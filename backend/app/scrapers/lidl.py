from __future__ import annotations

import json
import logging
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone

import httpx
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright
from sqlalchemy.orm import Session

from app.db.models import Company, Flyer, Store
from app.db.models.store_detail import StoreDetail
from app.dependencies import get_or_create_company

log = logging.getLogger(__name__)

COMPANY_NAME = "Lidl"
COMPANY_SLUG = "lidl"
LIDL_BASE = "https://www.lidl.se"
LIDL_STORES_URL = f"{LIDL_BASE}/s/sv-SE/butiker/"
LIDL_FLYERS_URL = f"{LIDL_BASE}/c/reklamblad/s10018018"
STORE_URL_PREFIX = "/s/sv-SE/butiker/"

MAX_CONCURRENT_REQUESTS = 15

USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/133.0.0.0 Safari/537.36"
)

DETAIL_FIELDS = (
    "about_url", "address", "postal_code", "city", "phone",
    "google_maps_url", "latitude", "longitude", "opening_hours", "special_hours",
)

SWEDISH_DAYS = ["Måndag", "Tisdag", "Onsdag", "Torsdag", "Fredag", "Lördag", "Söndag"]
DAY_INDEX = {d.lower(): i for i, d in enumerate(SWEDISH_DAYS)}


# ---------------------------------------------------------------------------
# Public API — stores
# ---------------------------------------------------------------------------

def discover_store_links() -> list[dict]:
    return _discover_all_store_urls()


def save_store_links(db: Session) -> int:
    company = get_or_create_company(db, COMPANY_NAME, COMPANY_SLUG)
    stores = _discover_all_store_urls()

    external_ids = [s["external_id"] for s in stores]
    existing = {
        s.external_id: s
        for s in db.query(Store).filter(Store.external_id.in_(external_ids)).all()
    }

    created = 0
    for s in stores:
        store = existing.get(s["external_id"])
        if store is None:
            store = Store(
                company_id=company.id,
                name=s["name"],
                chain="LIDL",
                external_id=s["external_id"],
            )
            db.add(store)
            created += 1

        store.company_id = company.id
        store.name = s["name"]
        store.chain = "LIDL"
        store.store_url = s["store_url"]
        store.weekly_deals_url = LIDL_FLYERS_URL

    db.commit()
    log.info("Saved Lidl stores: %d created, %d total", created, len(stores))
    return created


def scrape_store_info(
    db: Session,
    company_id: int,
    store_id: int | None = None,
    mode: str = "new",
    limit: int | None = None,
) -> dict:
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

    about_urls = {s.id: s.store_url for s in targets}

    existing_details = {
        sd.store_id: sd
        for sd in db.query(StoreDetail).filter(
            StoreDetail.store_id.in_([s.id for s in targets])
        ).all()
    }

    fetched = _fetch_store_infos_concurrent(about_urls)

    now = datetime.now(timezone.utc)
    created = 0
    updated = 0
    unchanged = 0
    failed = 0

    for store in targets:
        info = fetched.get(store.id)
        if not info:
            failed += 1
            continue

        info["about_url"] = store.store_url
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
# Public API — deals (flyers only for Lidl)
# ---------------------------------------------------------------------------

def scrape_store_deals(db: Session, company_id: int, store_id: int) -> dict:
    company = db.query(Company).filter(Company.id == company_id).first()
    if company is None:
        raise ValueError(f"Company {company_id} not found")

    store = db.query(Store).filter(
        Store.company_id == company_id, Store.id == store_id
    ).first()
    if store is None:
        raise ValueError(f"Store {store_id} not found for company {company_id}")

    flyers_data = _fetch_current_flyers()
    saved = 0
    for fl in flyers_data:
        if _save_flyer(db, store, fl):
            saved += 1

    return {
        "company_id": company.id,
        "company_name": company.name,
        "store_id": store.id,
        "store_name": store.name,
        "deals_found": 0,
        "deals_created": 0,
        "flyers_found": len(flyers_data),
        "flyers_created": saved,
    }


def scrape_company_store_deals(db: Session, company_id: int) -> dict:
    company = db.query(Company).filter(Company.id == company_id).first()
    if company is None:
        raise ValueError(f"Company {company_id} not found")

    stores = db.query(Store).filter(
        Store.company_id == company_id
    ).order_by(Store.id).all()
    flyers_data = _fetch_current_flyers()

    totals: dict[str, int | str] = {
        "company_id": company.id,
        "company_name": company.name,
        "stores_checked": len(stores),
        "stores_with_deals": 0,
        "deals_found": 0,
        "deals_created": 0,
        "flyers_found": len(flyers_data),
        "flyers_created": 0,
    }

    for fl in flyers_data:
        existing_store_ids = set(
            sid for (sid,) in db.query(Flyer.store_id).filter(
                Flyer.url == fl["url"],
                Flyer.store_id.in_([s.id for s in stores]),
            ).all()
        )
        for store in stores:
            if store.id in existing_store_ids:
                continue
            flyer = Flyer(
                store_id=store.id,
                url=fl["url"],
                valid_from=fl.get("valid_from"),
                valid_to=fl.get("valid_to"),
                week_number=fl.get("week_number"),
            )
            db.add(flyer)
            totals["flyers_created"] += 1

    db.commit()
    return totals


def scrape_first_store_deals(db: Session) -> dict:
    store = (
        db.query(Store)
        .join(Company)
        .filter(Company.slug == COMPANY_SLUG)
        .order_by(Store.id)
        .first()
    )
    if store is None:
        raise ValueError("No Lidl store found")

    flyers_data = _fetch_current_flyers()
    saved = 0
    for fl in flyers_data:
        if _save_flyer(db, store, fl):
            saved += 1

    return {
        "store_id": store.id,
        "store_name": store.name,
        "deals_found": 0,
        "deals_created": 0,
        "flyers_found": len(flyers_data),
        "flyers_created": saved,
    }


# ---------------------------------------------------------------------------
# Store discovery
# ---------------------------------------------------------------------------

def _discover_all_store_urls() -> list[dict]:
    resp = httpx.get(
        LIDL_STORES_URL, timeout=30.0,
        headers={"User-Agent": USER_AGENT}, follow_redirects=True,
    )
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")

    individual: list[dict] = []
    city_pages: list[dict] = []

    for a in soup.find_all("a", href=True):
        href = a["href"]
        if not href.startswith(STORE_URL_PREFIX):
            continue
        slug = href.removeprefix(STORE_URL_PREFIX).rstrip("/")
        if not slug:
            continue
        parts = slug.split("/")
        text = a.get_text(strip=True)
        if len(parts) >= 2 and parts[1]:
            individual.append({"slug": slug, "text": text, "href": href})
        elif len(parts) == 1:
            city_pages.append({"slug": slug, "text": text, "href": href})

    for city in city_pages:
        url = f"{LIDL_BASE}{city['href']}"
        try:
            r = httpx.get(
                url, timeout=30.0,
                headers={"User-Agent": USER_AGENT}, follow_redirects=True,
            )
            r.raise_for_status()
            cs = BeautifulSoup(r.text, "lxml")
            for a in cs.find_all("a", href=True):
                href = a["href"]
                if not href.startswith(STORE_URL_PREFIX):
                    continue
                slug = href.removeprefix(STORE_URL_PREFIX).rstrip("/")
                parts = slug.split("/")
                if len(parts) >= 2 and parts[1]:
                    individual.append({
                        "slug": slug,
                        "text": a.get_text(strip=True),
                        "href": href,
                    })
        except Exception as exc:
            log.error("Failed to expand city page %s: %s", url, exc)

    seen: set[str] = set()
    deduped: list[dict] = []
    city_count: dict[str, int] = {}
    for link in individual:
        if link["slug"] in seen:
            continue
        seen.add(link["slug"])
        city_slug = link["slug"].split("/")[0]
        city_count[city_slug] = city_count.get(city_slug, 0) + 1
        deduped.append(link)

    result: list[dict] = []
    for link in deduped:
        parts = link["slug"].split("/")
        city_slug = parts[0]
        address_slug = parts[1] if len(parts) > 1 else ""
        city_name = _humanize_slug(city_slug)

        if city_count.get(city_slug, 1) > 1:
            name = f"Lidl {city_name} {_humanize_slug(address_slug)}"
        else:
            name = f"Lidl {city_name}"

        result.append({
            "name": name,
            "chain": "LIDL",
            "store_url": f"{LIDL_BASE}{link['href'].rstrip('/')}/",
            "external_id": f"lidl:{link['slug']}",
        })

    log.info("Discovered %d Lidl stores", len(result))
    return result


def _humanize_slug(slug: str) -> str:
    return " ".join(slug.replace("-", " ").split()).title()


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
            except Exception as exc:
                log.error("Fetch crashed for %s: %s", about_urls[store_id], exc)

    failed_ids = [sid for sid in about_urls if sid not in results]
    if failed_ids:
        log.info("Retrying %d stores with browser rendering", len(failed_ids))
        for store_id in failed_ids:
            url = about_urls[store_id]
            html = _fetch_with_browser(url)
            if not html:
                continue
            info = _parse_store_page(BeautifulSoup(html, "lxml"))
            if info:
                results[store_id] = info

    return results


def _fetch_and_parse_store_info(store_url: str) -> dict | None:
    try:
        resp = httpx.get(
            store_url, timeout=30.0, follow_redirects=True,
            headers={"User-Agent": USER_AGENT},
        )
        resp.raise_for_status()
    except httpx.HTTPError as exc:
        log.warning("HTTP error fetching %s: %s", store_url, exc)
        return None

    return _parse_store_page(BeautifulSoup(resp.text, "lxml"))


def _fetch_with_browser(url: str) -> str | None:
    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True)
            page = browser.new_page(user_agent=USER_AGENT)
            try:
                page.goto(url, wait_until="domcontentloaded", timeout=30_000)
                page.wait_for_timeout(2_000)
                return page.content()
            finally:
                page.close()
                browser.close()
    except Exception as exc:
        log.error("Browser rendering failed for %s: %s", url, exc)
        return None


# ---------------------------------------------------------------------------
# Store page parsing
# ---------------------------------------------------------------------------

def _parse_store_page(soup: BeautifulSoup) -> dict | None:
    info: dict = {}

    bing_link = soup.find("a", href=re.compile(r"bing\.com/maps"))
    if bing_link:
        href = bing_link["href"]
        info["google_maps_url"] = href
        coord_match = re.search(r"pos\.([\d.-]+)_([\d.-]+)", href)
        if coord_match:
            info["latitude"] = float(coord_match.group(1))
            info["longitude"] = float(coord_match.group(2))

    page_text = soup.get_text("\n", strip=True)
    _parse_address_from_text(page_text, info)
    _parse_opening_hours(page_text, info)

    return info if info else None


def _parse_address_from_text(text: str, info: dict) -> None:
    for m in re.finditer(r",\s*(\d{3})\s?(\d{2})\s+", text):
        postal = m.group(1) + m.group(2)
        before = text[: m.start()].rstrip()

        line_start = before.rfind("\n")
        address = before[line_start + 1 :].strip() if line_start >= 0 else before.strip()
        if len(address) > 80 or not re.search(r"\d+\w?\s*$", address):
            continue

        after = text[m.end() : m.end() + 60].split("\n")[0].strip()
        city_match = re.match(r"([A-ZÅÄÖÉÈÜ]\w+(?:[\s\-][A-ZÅÄÖÉÈÜ]\w+){0,2})", after)
        if not city_match:
            continue

        info["address"] = address
        info["postal_code"] = postal
        info["city"] = city_match.group(1).strip()
        return


def _parse_opening_hours(text: str, info: dict) -> None:
    hours: list[dict] = []

    for m in re.finditer(
        r"(?:Helgfri\s+)?"
        r"([Mm]åndag|[Tt]isdag|[Oo]nsdag|[Tt]orsdag|[Ff]redag|[Ll]ördag|[Ss]öndag)"
        r"\s*[-–]\s*"
        r"([Mm]åndag|[Tt]isdag|[Oo]nsdag|[Tt]orsdag|[Ff]redag|[Ll]ördag|[Ss]öndag)"
        r"\s*:\s*(\d{1,2}[.:]\d{2})\s*[-–]\s*(\d{1,2}[.:]\d{2})",
        text,
    ):
        days = _expand_day_range(m.group(1).capitalize(), m.group(2).capitalize())
        hours.append({
            "days": days,
            "open": _normalize_time(m.group(3)),
            "close": _normalize_time(m.group(4)),
        })

    for m in re.finditer(
        r"(Måndag|Tisdag|Onsdag|Torsdag|Fredag|Lördag|Söndag)"
        r"\s*:\s*(?:(\d{1,2}[.:]\d{2})\s*[-–]\s*(\d{1,2}[.:]\d{2})|([Ss]tängt))",
        text,
    ):
        day = m.group(1)
        if any(day in h["days"] for h in hours):
            continue
        if m.group(4):
            hours.append({"days": [day], "open": None, "close": None})
        else:
            hours.append({
                "days": [day],
                "open": _normalize_time(m.group(2)),
                "close": _normalize_time(m.group(3)),
            })

    if hours:
        info["opening_hours"] = json.dumps(hours, ensure_ascii=False)


def _expand_day_range(start: str, end: str) -> list[str]:
    s_idx = DAY_INDEX.get(start.lower())
    e_idx = DAY_INDEX.get(end.lower())
    if s_idx is None or e_idx is None:
        return [start, end]
    days: list[str] = []
    i = s_idx
    while True:
        days.append(SWEDISH_DAYS[i])
        if i == e_idx:
            break
        i = (i + 1) % 7
    return days


def _normalize_time(val: str) -> str:
    val = val.strip().replace(".", ":")
    if ":" in val:
        return val.zfill(5)
    return f"{val.zfill(2)}:00"


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
# Flyers
# ---------------------------------------------------------------------------

def _fetch_current_flyers() -> list[dict]:
    try:
        resp = httpx.get(
            LIDL_FLYERS_URL, timeout=30.0,
            headers={"User-Agent": USER_AGENT}, follow_redirects=True,
        )
        resp.raise_for_status()
    except httpx.HTTPError as exc:
        log.error("Failed to fetch flyers page: %s", exc)
        return []

    soup = BeautifulSoup(resp.text, "lxml")
    flyers: list[dict] = []

    for a in soup.find_all("a", href=re.compile(r"/l/sv/reklamblad/")):
        href = a["href"]
        if href.startswith("/"):
            href = f"{LIDL_BASE}{href}"

        text = a.get_text(" ", strip=True)
        valid_from, valid_to, week_number = _parse_flyer_dates(text)

        flyers.append({
            "url": href,
            "title": text,
            "valid_from": valid_from,
            "valid_to": valid_to,
            "week_number": week_number,
        })

    seen: set[str] = set()
    unique: list[dict] = []
    for fl in flyers:
        if fl["url"] not in seen:
            seen.add(fl["url"])
            unique.append(fl)

    log.info("Found %d Lidl flyers", len(unique))
    return unique


def _parse_flyer_dates(
    text: str,
) -> tuple[datetime | None, datetime | None, int | None]:
    m = re.search(r"(\d{1,2})/(\d{1,2})\s*[-–]\s*(\d{1,2})/(\d{1,2})", text)
    if not m:
        return None, None, None

    year = datetime.now(timezone.utc).year
    try:
        valid_from = datetime(
            year, int(m.group(2)), int(m.group(1)), tzinfo=timezone.utc,
        )
        valid_to = datetime(
            year, int(m.group(4)), int(m.group(3)), 23, 59, 59, tzinfo=timezone.utc,
        )
        week_number = valid_to.isocalendar()[1]
        return valid_from, valid_to, week_number
    except ValueError:
        return None, None, None


def _save_flyer(db: Session, store: Store, flyer_info: dict) -> bool:
    url = flyer_info["url"]

    existing = db.query(Flyer).filter(
        Flyer.store_id == store.id, Flyer.url == url
    ).first()
    if existing:
        return False

    flyer = Flyer(
        store_id=store.id,
        url=url,
        valid_from=flyer_info.get("valid_from"),
        valid_to=flyer_info.get("valid_to"),
        week_number=flyer_info.get("week_number"),
    )
    db.add(flyer)
    db.commit()
    return True
