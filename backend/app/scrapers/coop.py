from __future__ import annotations

import hashlib
import logging
import os
import re
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
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

MAX_CONCURRENT_REQUESTS = 15

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

    about_urls = {s.id: s.store_url.rstrip("/") + "/om-butiken/" for s in targets}
    store_names = {s.id: s.name for s in targets}

    existing_details = {
        sd.store_id: sd
        for sd in db.query(StoreDetail).filter(
            StoreDetail.store_id.in_([s.id for s in targets])
        ).all()
    }

    log.info("Scraping store info for %d stores (mode=%s, concurrency=%d)", len(targets), mode, MAX_CONCURRENT_REQUESTS)
    fetched = _fetch_store_infos_concurrent(about_urls)

    now = datetime.now(timezone.utc)
    created = 0
    updated = 0
    unchanged = 0
    failed = 0

    for store in targets:
        info = fetched.get(store.id)
        if not info:
            log.error("No data scraped for store '%s' (id=%d): %s", store.name, store.id, about_urls[store.id])
            failed += 1
            continue

        _geocode(info, about_urls[store.id], store_names.get(store.id, ""))

        missing = [f for f in ("address", "postal_code", "city", "latitude", "longitude") if not info.get(f)]
        if missing:
            log.warning("Incomplete data for '%s': missing %s — %s", store.name, ", ".join(missing), about_urls[store.id])

        info["about_url"] = about_urls[store.id]
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
# Store info: concurrent fetch
# ---------------------------------------------------------------------------

def _fetch_store_infos_concurrent(about_urls: dict[int, str]) -> dict[int, dict]:
    results: dict[int, dict] = {}

    with ThreadPoolExecutor(max_workers=MAX_CONCURRENT_REQUESTS) as pool:
        future_to_id = {
            pool.submit(_fetch_and_parse_store_info, url): store_id
            for store_id, url in about_urls.items()
        }
        for future in as_completed(future_to_id):
            store_id = future_to_id[future]
            try:
                info = future.result()
                if info:
                    results[store_id] = info
                else:
                    log.warning("Static fetch returned no data: %s", about_urls[store_id])
            except Exception as exc:
                log.error("Static fetch crashed for %s: %s", about_urls[store_id], exc)

    failed_ids = [sid for sid in about_urls if sid not in results]
    if failed_ids:
        log.info("Retrying %d stores with browser rendering: %s",
                 len(failed_ids), [about_urls[sid] for sid in failed_ids])
        for store_id in failed_ids:
            url = about_urls[store_id]
            html = _fetch_store_info_with_browser(url)
            if not html:
                log.error("Browser fetch also failed: %s", url)
                continue
            info = _fetch_and_parse_store_info(url, html=html)
            if info:
                results[store_id] = info
            else:
                log.error("Parsing failed after browser render: %s", url)

    return results


def _apply_info(detail: StoreDetail, info: dict) -> None:
    for field in DETAIL_FIELDS:
        if field in info:
            setattr(detail, field, info[field])


def _has_changes(detail: StoreDetail, info: dict) -> bool:
    for field in DETAIL_FIELDS:
        if field in info and getattr(detail, field, None) != info[field]:
            return True
    return False


# ---------------------------------------------------------------------------
# Store info: fetch & parse
# ---------------------------------------------------------------------------

def _fetch_and_parse_store_info(about_url: str, html: str | None = None) -> dict | None:
    if html is None:
        try:
            resp = httpx.get(about_url, timeout=30.0, follow_redirects=True, headers={"User-Agent": USER_AGENT})
            resp.raise_for_status()
            html = resp.text
        except httpx.HTTPError as exc:
            log.warning("HTTP error fetching %s: %s", about_url, exc)
            return None

    soup = BeautifulSoup(html, "lxml")

    address_block = soup.select_one("div.Rc8wiCPU div.u-sizeFull div.u-marginTxxxsm")

    info: dict = {}

    if address_block:
        _parse_address_block(address_block, info)
    else:
        log.warning("No address block found: %s", about_url)

    maps_link = soup.select_one("a[href*='maps.google.com']")
    if maps_link:
        info["google_maps_url"] = maps_link.get("href")

    phone_link = soup.select_one("a[href^='tel:']")
    if phone_link:
        info["phone"] = phone_link.get_text(strip=True)

    _parse_opening_hours(soup, info)

    return info if info else None


def _fetch_store_info_with_browser(about_url: str) -> str | None:
    log.info("Browser rendering: %s", about_url)
    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True)
            page = browser.new_page(user_agent=USER_AGENT)
            try:
                page.goto(about_url, wait_until="domcontentloaded", timeout=30_000)
                page.wait_for_selector("div.Rc8wiCPU", timeout=10_000)
                return page.content()
            except PlaywrightTimeoutError:
                log.warning("Browser timeout waiting for content: %s", about_url)
                return None
            finally:
                page.close()
                browser.close()
    except Exception as exc:
        log.error("Browser rendering failed for %s: %s", about_url, exc)
        return None



def _parse_address_block(block, info: dict) -> None:
    for hidden in block.select("span.u-hiddenVisually"):
        hidden.decompose()

    text = block.get_text("\n", strip=True)
    lines = [line.strip() for line in text.split("\n") if line.strip()]

    if len(lines) < 2:
        return

    info["address"] = lines[1]

    for i, line in enumerate(lines[2:], start=2):
        postal_city = re.match(r"(\d{3}\s?\d{2})\s+(.+)", line)
        if postal_city:
            info["postal_code"] = postal_city.group(1).replace(" ", "")
            info["city"] = postal_city.group(2).strip()
            return

        postal_only = re.match(r"^(\d{3}\s?\d{2})$", line)
        if postal_only:
            info["postal_code"] = postal_only.group(1).replace(" ", "")
            if i + 1 < len(lines):
                info["city"] = lines[i + 1].strip()
            return


def _parse_opening_hours(soup, info: dict) -> None:
    sections = soup.select("div.Rc8wiCPU")

    for section in sections:
        heading = section.select_one("h3")
        if not heading:
            continue
        if "öppettider" not in heading.get_text(strip=True).lower():
            continue

        hours_container = section.select_one("div.u-sizeFull.u-lineHeightxLg")
        if not hours_container:
            continue

        hour_groups = hours_container.find_all("div", recursive=False)
        regular: list[str] = []
        special: list[str] = []
        target = regular

        for group in hour_groups:
            if "u-marginTsm" in (group.get("class") or []):
                target = special

            rows = group.select("div.u-flex.u-flexJustifySpaceBetween")
            for row in rows:
                day_el = row.select_one("div.Q3Ib28ir")
                time_el = row.select_one("div.u-whitespaceNoWrap")
                if day_el and time_el:
                    day = day_el.get_text(strip=True)
                    time_val = time_el.get_text(strip=True)
                    target.append(f"{day}: {time_val}")

        if regular:
            info["opening_hours"] = " | ".join(regular)
        if special:
            info["special_hours"] = " | ".join(special)
        break


NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"


def _geocode(info: dict, about_url: str = "", store_name: str = "") -> None:
    address = info.get("address")
    city = info.get("city")
    if not address and not store_name:
        return

    queries = []
    if address:
        parts = [address]
        if info.get("postal_code"):
            parts.append(info["postal_code"])
        if city:
            parts.append(city)
        parts.append("Sweden")
        queries.append(", ".join(parts))
    if store_name and city:
        queries.append(f"{store_name}, {city}, Sweden")
    if store_name:
        queries.append(f"{store_name}, Sweden")

    for query in queries:
        try:
            time.sleep(1.1)
            resp = httpx.get(
                NOMINATIM_URL,
                params={"q": query, "format": "json", "limit": 1, "countrycodes": "se"},
                headers={"User-Agent": "DealsApp/1.0"},
                timeout=10.0,
            )
            results = resp.json()
            if results:
                info["latitude"] = float(results[0]["lat"])
                info["longitude"] = float(results[0]["lon"])
                return
        except Exception as exc:
            log.error("Geocoding request failed for query='%s' (%s): %s", query, about_url, exc)
            return

    log.warning("Geocoding returned no results for any query (%s): tried %s", about_url, queries)


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

    parsed, flyer_url = _fetch_and_parse_store_deals(store.store_url)
    created = _save_deals(db, store, parsed)

    pdf_path, file_size = None, None
    if flyer_url and store.external_id:
        pdf_path, file_size = _download_flyer(flyer_url, store.external_id)
    _save_flyer(db, store, flyer_url, pdf_path, file_size)

    return {
        "store_id": store.id,
        "store_name": store.name,
        "deals_found": len(parsed),
        "deals_created": created,
        "flyer_url": flyer_url,
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

    for store in stores:
        if not store.store_url:
            continue
        totals["stores_checked"] += 1
        try:
            parsed, flyer_url = _fetch_and_parse_store_deals(store.store_url)
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
            _save_flyer(db, store, flyer_url, pdf_path, file_size)
            if pdf_path:
                totals["flyers_downloaded"] += 1

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

    parsed, flyer_url = _fetch_and_parse_store_deals(store.store_url)
    created = _save_deals(db, store, parsed)

    pdf_path, file_size = None, None
    if flyer_url and store.external_id:
        pdf_path, file_size = _download_flyer(flyer_url, store.external_id)
    _save_flyer(db, store, flyer_url, pdf_path, file_size)

    return {
        "company_id": company.id,
        "company_name": company.name,
        "store_id": store.id,
        "store_name": store.name,
        "deals_found": len(parsed),
        "deals_created": created,
        "flyer_url": flyer_url,
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

def _fetch_and_parse_store_deals(store_url: str) -> tuple[list[dict], str | None]:
    html = _fetch_store_html(store_url)
    deals = _parse_products_from_html(html, store_url)
    flyer_url = _extract_flyer_url(html)
    return deals, flyer_url


def _fetch_store_html(store_url: str) -> str:
    response = httpx.get(store_url, timeout=30.0, follow_redirects=True, headers={"User-Agent": USER_AGENT})
    response.raise_for_status()
    html = response.text
    if _html_has_product_cards(html) and not _html_has_offer_dialogs(html):
        return html
    return _fetch_store_html_with_browser(store_url)


def _fetch_store_html_with_browser(store_url: str) -> str:
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        page = browser.new_page(user_agent=USER_AGENT)
        try:
            page.goto(store_url, wait_until="domcontentloaded", timeout=60_000)
            try:
                page.wait_for_selector("li.Grid-cell article, article.ohKiwh8z", timeout=12_000)
            except PlaywrightTimeoutError:
                pass
            dialog_html = _collect_offer_dialog_html(page)
            page.wait_for_timeout(1_500)
            return page.content() + "\n" + dialog_html
        finally:
            page.close()
            browser.close()


def _collect_offer_dialog_html(page) -> str:
    fragments: list[str] = []
    buttons = page.locator("button").filter(
        has_text=re.compile(r"^(See|Se)\s+\d+\s+(items|varor)$", re.IGNORECASE)
    )

    for i in range(buttons.count()):
        button = buttons.nth(i)
        label = _clean(button.text_content() or "")
        if not _is_offer_dialog_button(label):
            continue
        try:
            button.scroll_into_view_if_needed(timeout=3_000)
            button.evaluate("el => el.click()")
            page.wait_for_selector(
                "div._111YdG_DialogContainer h1, div._111YdG_DialogContainer article.ohKiwh8z",
                timeout=6_000,
            )
            dialog = page.locator("div._111YdG_DialogContainer").last
            fragments.append(dialog.inner_html(timeout=3_000))
            dialog.locator("button.CM0Nmq_Button--icon").first.click(timeout=5_000, force=True)
            page.wait_for_timeout(150)
        except (PlaywrightTimeoutError, Exception):
            continue

    return "\n".join(fragments)


def _is_offer_dialog_button(label: str) -> bool:
    low = label.lower()
    return any(t in low for t in ["see ", "se "]) and any(t in low for t in [" items", " varor"])


def _html_has_offer_dialogs(html: str) -> bool:
    markers = ("See 2 items", "See 3 items", "See 4 items", "Se 2 varor", "Se 3 varor", "Se 4 varor")
    return any(m in html for m in markers)


def _html_has_product_cards(html: str) -> bool:
    markers = ('li class="Grid-cell', 'class="ohKiwh8z', 'containerclassname="ha6aAK6g"', 'class="slH8Imgo"')
    return any(m in html for m in markers)


# ---------------------------------------------------------------------------
# Deals: HTML parsing
# ---------------------------------------------------------------------------

def _parse_products_from_html(html: str, source_url: str) -> list[dict]:
    soup = BeautifulSoup(html, "lxml")
    items: list[dict] = []

    for article in soup.select("li.Grid-cell article"):
        name_el = article.select_one("h3")
        if name_el is None:
            continue
        name = _clean(name_el.get_text(" ", strip=True))
        if not name:
            continue

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

        items.append({
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
        })

    return items


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


def _save_flyer(db: Session, store: Store, flyer_url: str | None, pdf_path: str | None, file_size: int | None) -> bool:
    if not flyer_url:
        return False

    existing = db.query(Flyer).filter(Flyer.store_id == store.id, Flyer.url == flyer_url).first()
    if existing:
        if pdf_path and not existing.pdf_path:
            existing.pdf_path = pdf_path
            existing.file_size = file_size
            db.commit()
        return False

    flyer = Flyer(
        store_id=store.id,
        url=flyer_url,
        pdf_path=pdf_path,
        file_size=file_size,
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
