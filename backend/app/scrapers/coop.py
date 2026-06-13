from __future__ import annotations

import hashlib
import json
import logging
import os
import random
import re
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin
from xml.etree import ElementTree

import httpx
from bs4 import BeautifulSoup
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
from playwright.sync_api import sync_playwright
from sqlalchemy.orm import Session

from app.db.models import Company, Deal, Flyer, Store
from app.db.models.store_detail import StoreDetail
from app.dependencies import get_or_create_company

log = logging.getLogger(__name__)

COMPANY_NAME = "Coop"
COMPANY_SLUG = "coop"
COOP_SITEMAP_URL = "https://www.coop.se/sitemap_pages.xml"
COOP_STORE_PREFIX = "https://www.coop.se/butiker-erbjudanden/"

# Coop's own store API (the one www.coop.se uses client-side).
COOP_STORE_API_BASE = "https://proxy.api.coop.se/external/store"
# Public subscription key embedded in every coop.se page; refreshed automatically on 401.
COOP_STORE_API_KEY_DEFAULT = "990520e65cc44eef89e9e9045b57f4e9"
COOP_STORE_API_KEY_PATTERN = re.compile(r'"storeApiSubscriptionKey"\s*:\s*"([0-9a-f-]+)"')

# Polite scraping: fetch a small batch, then pause before the next one.
STORE_INFO_BATCH_SIZE = 5
STORE_INFO_REQUEST_DELAY = (0.5, 1.5)
STORE_INFO_BATCH_PAUSE = (4.0, 8.0)

FLYER_DIR = Path(os.environ.get("FLYER_DIR", "data/flyers"))
FLYER_DIR.mkdir(parents=True, exist_ok=True)

USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/133.0.0.0 Safari/537.36"
)

DETAIL_FIELDS = ("about_url", "address", "postal_code", "city", "phone", "google_maps_url", "latitude", "longitude", "opening_hours", "special_hours")


@dataclass(slots=True)
class CoopStoreLink:
    name: str
    concept: str
    slug: str
    store_url: str


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def discover_store_links() -> list[CoopStoreLink]:
    response = httpx.get(COOP_SITEMAP_URL, timeout=30.0)
    response.raise_for_status()

    root = ElementTree.fromstring(response.text)
    ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    seen: set[str] = set()
    stores: list[CoopStoreLink] = []

    for loc in root.findall("sm:url/sm:loc", ns):
        url = (loc.text or "").strip()
        if not url.startswith(COOP_STORE_PREFIX) or url in seen:
            continue

        parsed = _parse_store_url(url)
        if parsed is None:
            continue

        seen.add(url)
        concept, slug = parsed
        stores.append(
            CoopStoreLink(
                name=_humanize_slug(slug),
                concept=concept,
                slug=slug,
                store_url=url,
            )
        )

    stores.sort(key=lambda s: (s.concept, s.name))
    return stores


def save_store_links(db: Session) -> int:
    company = get_or_create_company(db, COMPANY_NAME, COMPANY_SLUG)
    links = discover_store_links()

    # Coop's sitemap contains stale entries (closed stores, renamed pages,
    # in-store restaurants); keep only entries the store API knows about.
    try:
        by_path, by_slug = _build_api_indexes(_fetch_store_api_map())
    except ValueError as exc:
        log.warning("Skipping sitemap validation, Coop store API unavailable: %s", exc)
    else:
        valid: list[CoopStoreLink] = []
        skipped: list[str] = []
        for link in links:
            path = _normalize_store_path(link.store_url)
            if path in by_path or path.rsplit("/", 1)[-1] in by_slug:
                valid.append(link)
            else:
                skipped.append(link.slug)
        if skipped:
            log.info("Skipping %d sitemap entries not in Coop store API: %s", len(skipped), skipped)
        links = valid

    external_ids = [_store_external_id(link.concept, link.slug) for link in links]
    existing = {
        s.external_id: s
        for s in db.query(Store).filter(Store.external_id.in_(external_ids)).all()
    }

    created = 0
    for link in links:
        ext_id = _store_external_id(link.concept, link.slug)
        store = existing.get(ext_id)
        if store is None:
            store = Store(company_id=company.id, name=link.name, chain=link.concept.upper(), external_id=ext_id)
            db.add(store)
            created += 1

        store.company_id = company.id
        store.name = link.name
        store.chain = link.concept.upper()
        store.store_url = link.store_url
        store.weekly_deals_url = None

    db.commit()
    return created


def scrape_store_info(db: Session, company_id: int, store_id: int | None = None, mode: str = "new", limit: int | None = None) -> dict:
    q = db.query(Store).filter(Store.company_id == company_id)
    if store_id is not None:
        q = q.filter(Store.id == store_id)

    stores = q.order_by(Store.id).all()
    if not stores:
        raise ValueError("No stores found")

    all_detail_store_ids = set(
        sid for (sid,) in db.query(StoreDetail.store_id).filter(
            StoreDetail.store_id.in_([s.id for s in stores])
        ).all()
    )

    if mode == "new":
        targets = [s for s in stores if s.id not in all_detail_store_ids and s.store_url]
    else:
        targets = [s for s in stores if s.store_url]

    if limit is not None:
        targets = targets[:limit]

    if not targets:
        return {
            "stores_total": len(stores),
            "stores_scraped": 0,
            "stores_created": 0,
            "stores_updated": 0,
            "stores_unchanged": 0,
            "stores_failed": 0,
        }

    existing_details = {
        sd.store_id: sd
        for sd in db.query(StoreDetail).filter(
            StoreDetail.store_id.in_([s.id for s in targets])
        ).all()
    }

    log.info("Scraping store info for %d stores (mode=%s, batch_size=%d)", len(targets), mode, STORE_INFO_BATCH_SIZE)

    api_by_path, api_by_slug = _build_api_indexes(_fetch_store_api_map())

    now = datetime.now(timezone.utc)
    created = 0
    updated = 0
    unchanged = 0
    failed = 0

    for i, store in enumerate(targets):
        _throttle(i)

        # Full-path match first; fall back to slug, since rebranded stores keep
        # their slug but move concept (e.g. /coop/x -> /coop-extra/x).
        path = _normalize_store_path(store.store_url)
        api_store = api_by_path.get(path) or api_by_slug.get(path.rsplit("/", 1)[-1])
        if api_store is None:
            log.error("Store '%s' (id=%d) not found in Coop store API: %s", store.name, store.id, store.store_url)
            failed += 1
            continue

        try:
            detail_data = _fetch_store_api_detail(api_store.get("ledgerAccountNumber"))
            info = _api_store_to_info(api_store, detail_data)
        except Exception as exc:
            log.error("Unexpected error scraping store '%s' (id=%d): %s", store.name, store.id, exc)
            failed += 1
            continue

        if not info:
            log.error("No data for store '%s' (id=%d): %s", store.name, store.id, store.store_url)
            failed += 1
            continue

        missing = [f for f in ("address", "postal_code", "city", "latitude", "longitude") if not info.get(f)]
        if missing:
            log.warning("Incomplete data for '%s': missing %s — %s", store.name, ", ".join(missing), store.store_url)

        info["about_url"] = store.store_url.rstrip("/") + "/om-butiken/"
        detail = existing_details.get(store.id)

        if detail is None:
            detail = StoreDetail(store_id=store.id)
            _apply_info(detail, info)
            detail.scraped_at = now
            detail.updated_at = now
            db.add(detail)
            created += 1
        else:
            detail.scraped_at = now
            if _has_changes(detail, info):
                _apply_info(detail, info)
                detail.updated_at = now
                updated += 1
            else:
                unchanged += 1

        if (i + 1) % STORE_INFO_BATCH_SIZE == 0:
            db.commit()

    db.commit()
    return {
        "stores_total": len(stores),
        "stores_scraped": len(targets),
        "stores_created": created,
        "stores_updated": updated,
        "stores_unchanged": unchanged,
        "stores_failed": failed,
    }


# ---------------------------------------------------------------------------
# Store info: Coop store API
# ---------------------------------------------------------------------------

_store_api_key: str = COOP_STORE_API_KEY_DEFAULT


def _throttle(index: int) -> None:
    if index == 0:
        return
    if index % STORE_INFO_BATCH_SIZE == 0:
        pause = random.uniform(*STORE_INFO_BATCH_PAUSE)
        log.info("Batch of %d done (%d stores so far), pausing %.1fs", STORE_INFO_BATCH_SIZE, index, pause)
        time.sleep(pause)
    else:
        time.sleep(random.uniform(*STORE_INFO_REQUEST_DELAY))


def _refresh_store_api_key() -> str | None:
    try:
        resp = httpx.get(
            COOP_STORE_PREFIX,
            timeout=30.0,
            follow_redirects=True,
            headers={"User-Agent": USER_AGENT},
        )
        resp.raise_for_status()
        match = COOP_STORE_API_KEY_PATTERN.search(resp.text)
        return match.group(1) if match else None
    except httpx.HTTPError as exc:
        log.error("Failed to refresh Coop store API key: %s", exc)
        return None


def _store_api_get(path: str, params: dict) -> httpx.Response | None:
    global _store_api_key

    url = f"{COOP_STORE_API_BASE}{path}"
    for attempt in range(3):
        try:
            resp = httpx.get(
                url,
                params=params,
                timeout=30.0,
                headers={
                    "User-Agent": USER_AGENT,
                    "Ocp-Apim-Subscription-Key": _store_api_key,
                },
            )
        except httpx.HTTPError as exc:
            log.warning("Coop store API request failed (attempt %d) %s: %s", attempt + 1, url, exc)
            time.sleep(random.uniform(3.0, 6.0))
            continue

        if resp.status_code == 401:
            log.info("Coop store API key rejected, refreshing from page config")
            new_key = _refresh_store_api_key()
            if new_key and new_key != _store_api_key:
                _store_api_key = new_key
                continue
            log.error("Could not obtain a valid Coop store API key")
            return None

        if resp.status_code == 429 or resp.status_code >= 500:
            log.warning("Coop store API returned %d (attempt %d): %s", resp.status_code, attempt + 1, url)
            time.sleep(random.uniform(5.0, 10.0))
            continue

        if resp.is_success:
            return resp

        log.error("Coop store API returned %d: %s", resp.status_code, url)
        return None

    return None


def _fetch_store_api_map() -> list[dict]:
    resp = _store_api_get("/stores/map", {"api-version": "v2", "conceptIds": "12,6,95", "invertFilter": "true"})
    if resp is None:
        raise ValueError("Coop store API unavailable, cannot scrape store info")
    stores = resp.json()
    log.info("Coop store API returned %d stores", len(stores))
    return stores


def _fetch_store_api_detail(ledger_account_number: str | None) -> dict | None:
    if not ledger_account_number:
        return None
    resp = _store_api_get(
        f"/stores/{ledger_account_number}",
        {"api-version": "v5", "onlyVisibleOpeningHours": "true"},
    )
    if resp is None:
        return None
    try:
        return resp.json()
    except ValueError as exc:
        log.error("Coop store API returned invalid JSON for %s: %s", ledger_account_number, exc)
        return None


def _normalize_store_path(url: str) -> str:
    path = re.sub(r"^https?://[^/]+", "", url or "")
    return path.strip("/").lower()


def _build_api_indexes(api_stores: list[dict]) -> tuple[dict[str, dict], dict[str, dict]]:
    by_path: dict[str, dict] = {}
    slug_counts: dict[str, int] = {}
    for s in api_stores:
        if not s.get("url"):
            continue
        path = _normalize_store_path(s["url"])
        by_path[path] = s
        slug = path.rsplit("/", 1)[-1]
        slug_counts[slug] = slug_counts.get(slug, 0) + 1

    by_slug = {
        path.rsplit("/", 1)[-1]: s
        for path, s in by_path.items()
        if slug_counts[path.rsplit("/", 1)[-1]] == 1
    }
    return by_path, by_slug


def _api_store_to_info(api_store: dict, detail_data: dict | None) -> dict:
    # The detail endpoint repeats the map fields; prefer it when available.
    source = detail_data or api_store
    info: dict = {}

    for src_field, dest_field in (("address", "address"), ("city", "city"), ("phone", "phone")):
        value = source.get(src_field) or api_store.get(src_field)
        if value:
            info[dest_field] = value

    postal = source.get("postalCode") or api_store.get("postalCode")
    if postal:
        info["postal_code"] = str(postal).replace(" ", "")

    lat = source.get("latitude") or api_store.get("latitude")
    lng = source.get("longitude") or api_store.get("longitude")
    if lat and lng:
        info["latitude"] = float(lat)
        info["longitude"] = float(lng)
        info["google_maps_url"] = f"https://maps.google.com/?q={lat},{lng}"

    if detail_data:
        regular = _convert_api_hours(detail_data.get("openingHours") or [])
        special = _convert_api_hours(detail_data.get("futureIrregularOpeningHours") or [], include_date=True)
        if regular:
            info["opening_hours"] = json.dumps(regular, ensure_ascii=False)
        if special:
            info["special_hours"] = json.dumps(special, ensure_ascii=False)

    return info


def _convert_api_hours(entries: list[dict], include_date: bool = False) -> list[dict]:
    result = []
    for entry in entries:
        if entry.get("visibleForEndUser") is False:
            continue
        label = (entry.get("text") or "").strip()
        if not label:
            continue
        is_closed = bool(entry.get("isClosed"))
        item = {
            "days": _expand_day_label(label),
            "open": None if is_closed else _trim_time(entry.get("openFrom")),
            "close": None if is_closed else _trim_time(entry.get("openTo")),
        }
        if include_date and entry.get("date"):
            item["date"] = str(entry["date"])[:10]
        result.append(item)
    return result


def _expand_day_label(label: str) -> list[str]:
    label = label.replace("–", "-").replace("—", "-").strip()
    if "-" in label:
        start, end = label.split("-", 1)
        start_idx = DAY_INDEX.get(start.strip().lower())
        end_idx = DAY_INDEX.get(end.strip().lower())
        if start_idx is not None and end_idx is not None:
            days = []
            i = start_idx
            while True:
                days.append(SWEDISH_DAYS[i])
                if i == end_idx:
                    break
                i = (i + 1) % 7
            return days
    for day in SWEDISH_DAYS:
        if label.lower() == day.lower():
            return [day]
    return [label]


def _trim_time(val: str | None) -> str | None:
    if not val:
        return None
    return val[:5]


def _apply_info(detail: StoreDetail, info: dict) -> None:
    for field in DETAIL_FIELDS:
        if field in info:
            setattr(detail, field, info[field])


def _has_changes(detail: StoreDetail, info: dict) -> bool:
    for field in DETAIL_FIELDS:
        if field in info and getattr(detail, field, None) != info[field]:
            return True
    return False


SWEDISH_DAYS = ["Måndag", "Tisdag", "Onsdag", "Torsdag", "Fredag", "Lördag", "Söndag"]
DAY_INDEX = {d.lower(): i for i, d in enumerate(SWEDISH_DAYS)}


# ---------------------------------------------------------------------------
# Deals: public API
# ---------------------------------------------------------------------------

def scrape_first_store_deals(db: Session) -> dict:
    store = (
        db.query(Store)
        .join(Company)
        .filter(Company.slug == COMPANY_SLUG)
        .order_by(Store.id)
        .first()
    )
    if store is None or not store.store_url:
        raise ValueError("No Coop store with store_url found")

    parsed, flyer_url, week_number = _fetch_and_parse_store_deals(store.store_url)
    created = _save_deals(db, store, parsed)

    pdf_path, file_size = None, None
    if flyer_url and store.external_id:
        pdf_path, file_size = _download_flyer(flyer_url, store.external_id)
    _save_flyer(db, store, flyer_url, pdf_path, file_size, week_number)

    return {
        "store_id": store.id,
        "store_name": store.name,
        "deals_found": len(parsed),
        "deals_created": created,
        "flyer_url": flyer_url,
        "week_number": week_number,
    }


def scrape_company_store_deals(db: Session, company_id: int) -> dict:
    company = db.query(Company).filter(Company.id == company_id).first()
    if company is None:
        raise ValueError(f"Company {company_id} not found")

    stores = db.query(Store).filter(Store.company_id == company_id).order_by(Store.id).all()

    totals: dict[str, int | str] = {
        "company_id": company.id,
        "company_name": company.name,
        "stores_checked": 0,
        "stores_with_deals": 0,
        "deals_found": 0,
        "deals_created": 0,
        "flyers_downloaded": 0,
    }

    pw = sync_playwright().start()
    browser = pw.chromium.launch(headless=True)
    try:
        for store in stores:
            if not store.store_url:
                continue
            totals["stores_checked"] += 1
            try:
                parsed, flyer_url, week_number = _fetch_and_parse_store_deals(store.store_url, browser)
            except Exception as exc:
                log.error("Failed to scrape deals for store '%s' (id=%d): %s", store.name, store.id, exc)
                continue
            if not parsed:
                continue
            totals["stores_with_deals"] += 1
            totals["deals_found"] += len(parsed)
            totals["deals_created"] += _save_deals(db, store, parsed)

            if flyer_url and store.external_id:
                pdf_path, file_size = _download_flyer(flyer_url, store.external_id)
                _save_flyer(db, store, flyer_url, pdf_path, file_size, week_number)
                if pdf_path:
                    totals["flyers_downloaded"] += 1
    finally:
        browser.close()
        pw.stop()

    return totals


def scrape_store_deals(db: Session, company_id: int, store_id: int) -> dict:
    company = db.query(Company).filter(Company.id == company_id).first()
    if company is None:
        raise ValueError(f"Company {company_id} not found")

    store = db.query(Store).filter(Store.company_id == company_id, Store.id == store_id).first()
    if store is None:
        raise ValueError(f"Store {store_id} not found for company {company_id}")
    if not store.store_url:
        raise ValueError(f"Store {store_id} has no store_url")

    parsed, flyer_url, week_number = _fetch_and_parse_store_deals(store.store_url)
    created = _save_deals(db, store, parsed)

    pdf_path, file_size = None, None
    if flyer_url and store.external_id:
        pdf_path, file_size = _download_flyer(flyer_url, store.external_id)
    _save_flyer(db, store, flyer_url, pdf_path, file_size, week_number)

    return {
        "company_id": company.id,
        "company_name": company.name,
        "store_id": store.id,
        "store_name": store.name,
        "deals_found": len(parsed),
        "deals_created": created,
        "flyer_url": flyer_url,
        "week_number": week_number,
    }


# ---------------------------------------------------------------------------
# URL helpers
# ---------------------------------------------------------------------------

def _parse_store_url(url: str) -> tuple[str, str] | None:
    path = url.removeprefix(COOP_STORE_PREFIX).strip("/")
    parts = [p for p in path.split("/") if p]
    if len(parts) != 2:
        return None
    return parts[0], parts[1]


def _humanize_slug(slug: str) -> str:
    return " ".join(slug.replace("-", " ").split()).title()


def _store_external_id(concept: str, slug: str) -> str:
    return f"{COMPANY_SLUG}:{concept}:{slug}"


def _deal_external_id(source_url: str, name: str, brand: str | None, size: str | None, deal_text: str | None) -> str:
    raw = "|".join([source_url, name, brand or "", size or "", deal_text or ""])
    digest = hashlib.sha1(raw.encode()).hexdigest()
    return f"{COMPANY_SLUG}:deal:{digest}"


# ---------------------------------------------------------------------------
# Deals: HTML fetch
# ---------------------------------------------------------------------------

def _fetch_and_parse_store_deals(store_url: str, browser=None) -> tuple[list[dict], str | None, int | None]:
    html = _fetch_store_html_with_browser(store_url, browser)
    deals = _parse_products_from_html(html, store_url)
    flyer_url = _extract_flyer_url(html)
    week_number = _extract_week_number(html)
    return deals, flyer_url, week_number


def _fetch_store_html_with_browser(store_url: str, browser=None) -> str:
    own_browser = browser is None
    pw_instance = None
    if own_browser:
        pw_instance = sync_playwright().start()
        browser = pw_instance.chromium.launch(headless=True)

    page = browser.new_page(user_agent=USER_AGENT)
    try:
        page.goto(store_url, wait_until="domcontentloaded", timeout=60_000)
        try:
            page.wait_for_selector("li.Grid-cell article, article.ohKiwh8z", timeout=12_000)
        except PlaywrightTimeoutError:
            pass

        dialog_html = ""
        try:
            page.wait_for_selector(
                "button:has-text('varor'), button:has-text('items')",
                timeout=3_000,
            )
            dialog_html = _collect_offer_dialog_html(page)
        except PlaywrightTimeoutError:
            pass

        html = page.content()
        if dialog_html:
            html = html.replace("</body>", dialog_html + "\n</body>")
        return html
    finally:
        page.close()
        if own_browser:
            browser.close()
            pw_instance.stop()


def _collect_offer_dialog_html(page) -> str:
    fragments: list[str] = []
    buttons = page.locator("button").filter(
        has_text=re.compile(r"(See|Se)\s+\d+\s+(items|varor)", re.IGNORECASE)
    )

    count = buttons.count()
    log.info("Found %d 'Se varor' dialog buttons", count)

    for i in range(count):
        button = buttons.nth(i)
        label = _clean(button.text_content() or "")
        if not _is_offer_dialog_button(label):
            continue
        try:
            button.scroll_into_view_if_needed(timeout=3_000)
            button.evaluate("el => el.click()")
            page.wait_for_selector(
                "div._111YdG_DialogContainer article.ohKiwh8z",
                timeout=5_000,
            )
            dialog = page.locator("div._111YdG_DialogContainer").last
            html = dialog.inner_html(timeout=3_000)
            fragments.append(html)
            log.info("Collected dialog '%s' (%d chars)", label, len(html))
            dialog.locator("button.CM0Nmq_Button--icon").first.click(timeout=3_000, force=True)
            page.wait_for_timeout(200)
        except Exception as exc:
            log.warning("Failed to collect dialog '%s': %s", label, exc)
            continue

    log.info("Collected %d dialog fragments", len(fragments))
    return "\n".join(fragments)


def _is_offer_dialog_button(label: str) -> bool:
    low = label.lower()
    return any(t in low for t in ["see ", "se "]) and any(t in low for t in [" items", " varor"])


# ---------------------------------------------------------------------------
# Deals: HTML parsing
# ---------------------------------------------------------------------------

def _parse_products_from_html(html: str, source_url: str) -> list[dict]:
    soup = BeautifulSoup(html, "lxml")
    items: list[dict] = []
    seen: set[int] = set()

    for article in soup.select("li.Grid-cell article, article.ohKiwh8z"):
        art_id = id(article)
        if art_id in seen:
            continue
        seen.add(art_id)

        parsed = _parse_single_article(article, source_url)
        if parsed:
            items.append(parsed)

    return items


def _parse_single_article(article, source_url: str) -> dict | None:
    name_el = article.select_one("h3")
    if name_el is None:
        return None
    name = _clean(name_el.get_text(" ", strip=True))
    if not name:
        return None

    meta_rows = article.select("div.uLmN8HjX")
    brand, size, description = None, None, None

    if meta_rows:
        spans = meta_rows[0].find_all("span")
        if spans:
            brand = _clean(spans[0].get_text(" ", strip=True)).rstrip(".")
        if len(spans) > 1:
            size = _clean(spans[1].get_text(" ", strip=True))
    if len(meta_rows) > 1:
        description = _clean(meta_rows[1].get_text(" ", strip=True))

    image_url = _extract_image_url(article)
    price_label = _extract_price_label(article)
    is_membership = _is_membership_price(price_label, article)

    deal_text = _normalize_deal_text(
        _clean(" ".join(s.get_text(" ", strip=True) for s in article.select("div.slH8Imgo span")))
    )
    aria_label = _get_aria_label(article)
    if not deal_text:
        deal_text = _normalize_deal_text(_extract_deal_text_from_aria(aria_label))

    extra_bits = [_clean(n.get_text(" ", strip=True)) for n in article.select("div.UWFn16pY div") if _clean(n.get_text(" ", strip=True))]
    extra_info = " | ".join(extra_bits) if extra_bits else None

    comparison_price = next((b for b in extra_bits if _looks_like_comparison_price(b)), None)
    if comparison_price is None:
        comparison_price = _extract_comparison_price_from_aria(aria_label)

    return {
        "external_id": _deal_external_id(source_url, name, brand, size, deal_text),
        "name": name,
        "brand": brand,
        "size": size,
        "description": description,
        "image_url": image_url,
        "price_label": price_label,
        "is_membership_price": is_membership,
        "deal_text": deal_text or None,
        "comparison_price": comparison_price,
        "extra_info": extra_info,
    }


def _clean(value: str | None) -> str:
    if not value:
        return ""
    return " ".join(value.split())


def _extract_image_url(article) -> str | None:
    img = article.select_one("img")
    if img is None:
        return None
    url = img.get("src") or img.get("srcset", "").split(" ")[0]
    if url and url.startswith("//"):
        url = urljoin("https:", url)
    return url or None


def _get_aria_label(article) -> str:
    btn = article.select_one("button[aria-label]")
    return btn.get("aria-label", "") if btn else ""


def _extract_price_label(article) -> str | None:
    for node in article.find_all("div"):
        text = _clean(node.get_text(" ", strip=True))
        if text and text.upper() == text and len(text) <= 20 and "KR" not in text:
            if any(w in text for w in ["MEDLEMSPRIS", "PRIS"]):
                return text
    return None


def _is_membership_price(price_label: str | None, article) -> bool:
    candidates = [price_label or ""]
    btn = article.select_one("button[aria-label]")
    if btn:
        candidates.append(btn.get("aria-label", ""))
    candidates.append(_clean(article.get_text(" ", strip=True)))
    lowered = " | ".join(candidates).lower()
    return any(n in lowered for n in ["medlemspris", "membership price", "member price"])


def _extract_deal_text_from_aria(value: str) -> str | None:
    if not value:
        return None
    for segment in (_clean(s) for s in value.split(",")):
        low = segment.lower()
        if any(t in low for t in [" för ", " for ", "/kg", "/ pc", "/pc", " per ", "/ mix"]):
            return segment
    return None


def _normalize_deal_text(value: str | None) -> str | None:
    if not value:
        return None
    text = _clean(value)
    text = re.sub(r"\b(kr)(?:\s+\1\b)+", r"\1", text, flags=re.IGNORECASE)
    text = re.sub(r"(/ ?[A-Za-z]+)(?:\s+\1\b)+", r"\1", text, flags=re.IGNORECASE)
    for old, new in [("kr / kg", "kr/kg"), ("kr / pc", "kr/pc"), ("kr / st", "kr/st")]:
        text = text.replace(old, new)
    return text or None


def _extract_comparison_price_from_aria(value: str) -> str | None:
    if not value:
        return None
    for segment in (_clean(s) for s in value.split(",")):
        if _looks_like_comparison_price(segment):
            return segment
    for marker in ["Jämförpris", "Compare price", "Comparison price"]:
        if marker in value:
            tail = value.split(marker, 1)[1].strip(" ,")
            if tail:
                return tail
    return None


def _looks_like_comparison_price(value: str) -> bool:
    low = value.lower()
    return any(t in low for t in ["jfr-pris", "jämförpris", "compare price", "comparison price"])


# ---------------------------------------------------------------------------
# Deals: DB persistence
# ---------------------------------------------------------------------------

def _save_deals(db: Session, store: Store, parsed: list[dict]) -> int:
    parsed = _dedupe(parsed)
    if not parsed:
        return 0

    ext_ids = [p["external_id"] for p in parsed if p["external_id"]]
    existing = {
        d.external_id: d
        for d in db.query(Deal).filter(Deal.external_id.in_(ext_ids)).all()
    } if ext_ids else {}

    now = datetime.now(timezone.utc)
    created = 0

    for item in parsed:
        deal = existing.get(item["external_id"])
        if deal is None:
            deal = Deal(store_id=store.id, chain=store.chain, external_id=item["external_id"], name=item["name"])
            db.add(deal)
            created += 1

        deal.store_id = store.id
        deal.chain = store.chain
        deal.name = item["name"]
        deal.brand = item["brand"]
        deal.size = item["size"]
        deal.description = item["description"]
        deal.image_url = item["image_url"]
        deal.price_label = item["price_label"]
        deal.is_membership_price = bool(item["is_membership_price"])
        deal.deal_text = item["deal_text"]
        deal.comparison_price = item["comparison_price"]
        deal.extra_info = item["extra_info"]
        deal.source_url = store.store_url
        deal.scraped_at = now

    db.commit()
    return created


def _extract_week_number(html: str) -> int | None:
    match = re.search(r"[Vv]ecka\s+(\d{1,2})", html)
    if match:
        return int(match.group(1))
    return None


def _extract_flyer_url(html: str) -> str | None:
    soup = BeautifulSoup(html, "lxml")
    for a in soup.find_all("a", href=True):
        href = a["href"]
        text = (a.get_text(strip=True) or "").lower()
        if "dr.coop.se" in href:
            return href
        if any(kw in text for kw in ["öppna pdf", "reklamblad", "veckoblad"]):
            return href
    return None


def _download_flyer(flyer_url: str, store_external_id: str) -> tuple[str | None, int | None]:
    safe_name = re.sub(r"[^a-zA-Z0-9_-]", "_", store_external_id)
    dest = FLYER_DIR / f"{safe_name}.pdf"
    try:
        resp = httpx.get(flyer_url, timeout=60.0, follow_redirects=True, headers={"User-Agent": USER_AGENT})
        resp.raise_for_status()
        dest.write_bytes(resp.content)
        file_size = len(resp.content)
        log.info("Flyer saved: %s (%d bytes)", dest, file_size)
        return str(dest), file_size
    except Exception as exc:
        log.error("Failed to download flyer from %s: %s", flyer_url, exc)
        return None, None


def _save_flyer(db: Session, store: Store, flyer_url: str | None, pdf_path: str | None, file_size: int | None, week_number: int | None = None) -> bool:
    if not flyer_url:
        return False

    existing = db.query(Flyer).filter(Flyer.store_id == store.id, Flyer.url == flyer_url).first()
    if existing:
        if pdf_path and not existing.pdf_path:
            existing.pdf_path = pdf_path
            existing.file_size = file_size
        if week_number and not existing.week_number:
            existing.week_number = week_number
        db.commit()
        return False

    flyer = Flyer(
        store_id=store.id,
        url=flyer_url,
        pdf_path=pdf_path,
        file_size=file_size,
        week_number=week_number,
    )
    db.add(flyer)
    db.commit()
    return True


def _dedupe(items: list[dict]) -> list[dict]:
    seen: dict[str, dict] = {}
    for item in items:
        ext_id = item.get("external_id")
        if ext_id:
            seen[ext_id] = item
    return list(seen.values())
