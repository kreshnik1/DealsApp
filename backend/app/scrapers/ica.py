from __future__ import annotations

import json
import logging
import os
import random
import re
import time
from datetime import datetime, timezone
from pathlib import Path

import httpx
from playwright.sync_api import sync_playwright
from sqlalchemy.orm import Session

from app.db.models import Company, Deal, Flyer, Product, Store
from app.db.models.store_detail import StoreDetail
from app.dependencies import get_or_create_company

log = logging.getLogger(__name__)

COMPANY_NAME = "ICA"
COMPANY_SLUG = "ica"
ICA_STORES_URL = "https://www.ica.se/butiker/"
ICA_OFFERS_PREFIX = "https://www.ica.se/erbjudanden/"

# Polite scraping: fetch a small batch, then pause before the next one.
STORE_INFO_BATCH_SIZE = 5
STORE_INFO_REQUEST_DELAY = (1.0, 2.5)
STORE_INFO_BATCH_PAUSE = (6.0, 12.0)

FLYER_DIR = Path(os.environ.get("FLYER_DIR", "data/flyers"))
FLYER_DIR.mkdir(parents=True, exist_ok=True)

USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/133.0.0.0 Safari/537.36"
)

DETAIL_FIELDS = (
    "about_url", "address", "postal_code", "city", "phone",
    "google_maps_url", "latitude", "longitude", "opening_hours", "special_hours",
)

PROFILE_CHAIN = {
    "Nära": "ICA NÄRA",
    "Supermarket": "ICA SUPERMARKET",
    "Kvantum": "ICA KVANTUM",
    "Maxi": "MAXI ICA",
}

SWEDISH_DAYS = ["Måndag", "Tisdag", "Onsdag", "Torsdag", "Fredag", "Lördag", "Söndag"]
DAY_INDEX = {d.lower(): i for i, d in enumerate(SWEDISH_DAYS)}


# ---------------------------------------------------------------------------
# Public API — stores
# ---------------------------------------------------------------------------

def discover_store_links() -> list[dict]:
    return _fetch_slim_stores()


def save_store_links(db: Session) -> int:
    company = get_or_create_company(db, COMPANY_NAME, COMPANY_SLUG)
    slim_stores = _fetch_slim_stores()

    external_ids = [f"ica:{s['accountNumber']}" for s in slim_stores]
    existing = {
        s.external_id: s
        for s in db.query(Store).filter(Store.external_id.in_(external_ids)).all()
    }

    created = 0
    for s in slim_stores:
        ext_id = f"ica:{s['accountNumber']}"
        chain = PROFILE_CHAIN.get(s["profile"], s["profile"].upper())
        store_url = s.get("bhsUrl", "")
        slug = store_url.rstrip("/").rsplit("/", 1)[-1] if store_url else ""
        deals_url = f"{ICA_OFFERS_PREFIX}{slug}/" if slug else None

        store = existing.get(ext_id)
        if store is None:
            store = Store(
                company_id=company.id,
                name=s["storeName"],
                chain=chain,
                external_id=ext_id,
            )
            db.add(store)
            created += 1

        store.company_id = company.id
        store.name = s["storeName"]
        store.chain = chain
        store.store_url = store_url
        store.weekly_deals_url = deals_url

    db.commit()
    log.info("Saved ICA stores: %d created, %d total", created, len(slim_stores))
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

    now = datetime.now(timezone.utc)
    created = 0
    updated = 0
    unchanged = 0
    failed = 0

    existing_details = {
        sd.store_id: sd
        for sd in db.query(StoreDetail).filter(
            StoreDetail.store_id.in_([s.id for s in targets])
        ).all()
    }

    log.info("Scraping store info for %d stores (mode=%s, batch_size=%d)", len(targets), mode, STORE_INFO_BATCH_SIZE)

    # Coordinate/address fallback: the store directory lists lat/lng for every store.
    slim_by_account: dict[str, dict] = {}
    try:
        slim_by_account = {str(s["accountNumber"]): s for s in _fetch_slim_stores() if s.get("accountNumber")}
    except Exception as exc:
        log.warning("Could not fetch slim store list for fallback data: %s", exc)

    for i, store in enumerate(targets):
        _throttle(i)

        try:
            info = _fetch_store_info_static(store.store_url)
            if info is None:
                log.info("Static fetch failed, falling back to browser: %s", store.store_url)
                info = _fetch_store_info_from_page(store.store_url)
        except Exception as exc:
            log.error("Unexpected error scraping store '%s' (id=%d): %s", store.name, store.id, exc)
            failed += 1
            continue

        if not info:
            log.error("No data scraped for store '%s' (id=%d): %s", store.name, store.id, store.store_url)
            failed += 1
            continue

        account_number = (store.external_id or "").removeprefix("ica:")
        _apply_slim_fallback(info, slim_by_account.get(account_number))

        missing = [f for f in ("address", "postal_code", "city", "latitude", "longitude") if not info.get(f)]
        if missing:
            log.warning("Incomplete data for '%s': missing %s — %s", store.name, ", ".join(missing), store.store_url)

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
# Public API — deals
# ---------------------------------------------------------------------------

def scrape_store_deals(db: Session, company_id: int, store_id: int) -> dict:
    company = db.query(Company).filter(Company.id == company_id).first()
    if company is None:
        raise ValueError(f"Company {company_id} not found")

    store = db.query(Store).filter(Store.company_id == company_id, Store.id == store_id).first()
    if store is None:
        raise ValueError(f"Store {store_id} not found for company {company_id}")
    if not store.weekly_deals_url:
        raise ValueError(f"Store {store_id} has no weekly_deals_url")

    parsed, flyer_url, week_number = _fetch_and_parse_store_deals(store.weekly_deals_url)
    deals_created, products_created = _save_deals(db, store, parsed)

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
        "deals_created": deals_created,
        "products_found": sum(len(d.get("_eans", [])) for d in parsed),
        "products_created": products_created,
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
        "products_found": 0,
        "products_created": 0,
        "flyers_downloaded": 0,
    }

    pw = sync_playwright().start()
    browser = pw.chromium.launch(headless=True)
    try:
        for store in stores:
            if not store.weekly_deals_url:
                continue
            totals["stores_checked"] += 1
            try:
                parsed, flyer_url, week_number = _fetch_and_parse_store_deals(
                    store.weekly_deals_url, browser
                )
            except Exception as exc:
                log.error("Failed deals for '%s' (id=%d): %s", store.name, store.id, exc)
                continue
            if not parsed:
                continue
            totals["stores_with_deals"] += 1
            totals["deals_found"] += len(parsed)
            totals["products_found"] += sum(len(d.get("_eans", [])) for d in parsed)
            deals_created, products_created = _save_deals(db, store, parsed)
            totals["deals_created"] += deals_created
            totals["products_created"] += products_created

            if flyer_url and store.external_id:
                pdf_path, file_size = _download_flyer(flyer_url, store.external_id)
                _save_flyer(db, store, flyer_url, pdf_path, file_size, week_number)
                if pdf_path:
                    totals["flyers_downloaded"] += 1
    finally:
        browser.close()
        pw.stop()

    return totals


def scrape_first_store_deals(db: Session) -> dict:
    store = (
        db.query(Store)
        .join(Company)
        .filter(Company.slug == COMPANY_SLUG)
        .order_by(Store.id)
        .first()
    )
    if store is None or not store.weekly_deals_url:
        raise ValueError("No ICA store with weekly_deals_url found")

    parsed, flyer_url, week_number = _fetch_and_parse_store_deals(store.weekly_deals_url)
    deals_created, products_created = _save_deals(db, store, parsed)

    pdf_path, file_size = None, None
    if flyer_url and store.external_id:
        pdf_path, file_size = _download_flyer(flyer_url, store.external_id)
    _save_flyer(db, store, flyer_url, pdf_path, file_size, week_number)

    return {
        "store_id": store.id,
        "store_name": store.name,
        "deals_found": len(parsed),
        "deals_created": deals_created,
        "products_found": sum(len(d.get("_eans", [])) for d in parsed),
        "products_created": products_created,
        "flyer_url": flyer_url,
        "week_number": week_number,
    }


# ---------------------------------------------------------------------------
# Store discovery: __INITIAL_DATA__ extraction
# ---------------------------------------------------------------------------

def _throttle(index: int) -> None:
    if index == 0:
        return
    if index % STORE_INFO_BATCH_SIZE == 0:
        pause = random.uniform(*STORE_INFO_BATCH_PAUSE)
        log.info("Batch of %d done (%d stores so far), pausing %.1fs", STORE_INFO_BATCH_SIZE, index, pause)
        time.sleep(pause)
    else:
        time.sleep(random.uniform(*STORE_INFO_REQUEST_DELAY))


def _extract_embedded_json(html: str, key: str) -> str | None:
    """Extract the JSON object or array following '"key":' via bracket matching.

    ICA pages embed window.__INITIAL_DATA__ server-side, but the full blob
    contains JS literals (undefined, new Map(...)), so only the needed
    fragment is extracted and parsed.
    """
    idx = html.find(f'"{key}":')
    if idx == -1:
        return None
    start = idx + len(key) + 3
    while start < len(html) and html[start] in " \t\r\n":
        start += 1
    if start >= len(html) or html[start] not in "{[":
        return None

    open_char = html[start]
    close_char = "}" if open_char == "{" else "]"
    depth, in_str, esc = 0, False, False
    for i in range(start, len(html)):
        c = html[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == open_char:
                depth += 1
            elif c == close_char:
                depth -= 1
                if depth == 0:
                    return html[start:i + 1]
    return None


def _parse_embedded_json(html: str, key: str):
    fragment = _extract_embedded_json(html, key)
    if fragment is None:
        return None
    fragment = re.sub(r":\s*undefined\b", ":null", fragment)
    try:
        return json.loads(fragment)
    except ValueError as exc:
        log.warning("Failed to parse embedded JSON for key '%s': %s", key, exc)
        return None


def _fetch_html(url: str, attempts: int = 2) -> str | None:
    for attempt in range(attempts):
        try:
            resp = httpx.get(url, timeout=30.0, follow_redirects=True, headers={"User-Agent": USER_AGENT})
            resp.raise_for_status()
            return resp.text
        except httpx.HTTPError as exc:
            log.warning("HTTP error fetching %s (attempt %d): %s", url, attempt + 1, exc)
            if attempt + 1 < attempts:
                time.sleep(random.uniform(3.0, 6.0))
    return None


def _fetch_slim_stores() -> list[dict]:
    html = _fetch_html(ICA_STORES_URL)
    if html:
        slim = _parse_embedded_json(html, "slimStores")
        if isinstance(slim, list) and slim:
            log.info("Discovered %d ICA stores from static __INITIAL_DATA__", len(slim))
            return slim

    log.info("Static slim store extraction failed, falling back to browser")
    return _fetch_slim_stores_browser()


def _fetch_slim_stores_browser() -> list[dict]:
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        page = browser.new_page(user_agent=USER_AGENT)
        page.goto(ICA_STORES_URL, wait_until="domcontentloaded", timeout=60_000)
        page.wait_for_timeout(3_000)

        stores_json = page.evaluate('''() => {
            const stores = window.__INITIAL_DATA__.SlimStores.slimStores._rawValue;
            return JSON.stringify(stores.map(s => ({
                storeId: s.storeId,
                accountNumber: s.accountNumber,
                storeName: s.storeName,
                profile: s.profile,
                address: s.address,
                lat: s.lat,
                lng: s.lng,
                bhsUrl: s.bhsUrl
            })));
        }''')

        page.close()
        browser.close()

    stores = json.loads(stores_json)
    log.info("Discovered %d ICA stores from __INITIAL_DATA__", len(stores))
    return stores


# ---------------------------------------------------------------------------
# Store info: from individual store page __INITIAL_DATA__
# ---------------------------------------------------------------------------

def _fetch_store_info_static(store_url: str) -> dict | None:
    html = _fetch_html(store_url)
    if not html:
        return None
    model = _parse_embedded_json(html, "storeInfoModel")
    if not isinstance(model, dict) or not model:
        log.warning("No storeInfoModel in static page: %s", store_url)
        return None
    return _model_to_info(model)


def _apply_slim_fallback(info: dict, slim: dict | None) -> None:
    if not slim:
        return

    if not info.get("latitude") and slim.get("lat"):
        try:
            info["latitude"] = float(slim["lat"])
            info["longitude"] = float(slim["lng"])
        except (TypeError, ValueError, KeyError):
            info.pop("latitude", None)

    addr = slim.get("address") or {}
    if isinstance(addr, dict):
        if not info.get("address") and addr.get("street"):
            info["address"] = addr["street"]
        if not info.get("postal_code") and addr.get("postalCode"):
            info["postal_code"] = str(addr["postalCode"]).replace(" ", "")
        if not info.get("city") and addr.get("city"):
            info["city"] = addr["city"]


def _fetch_store_info_from_page(store_url: str, browser=None) -> dict | None:
    own_browser = browser is None
    pw_instance = None
    if own_browser:
        pw_instance = sync_playwright().start()
        browser = pw_instance.chromium.launch(headless=True)

    page = browser.new_page(user_agent=USER_AGENT)
    try:
        page.goto(store_url, wait_until="domcontentloaded", timeout=60_000)
        page.wait_for_timeout(2_000)

        model_json = page.evaluate('''() => {
            try {
                return JSON.stringify(window.__INITIAL_DATA__.epi.jsonData.storeInfoModel);
            } catch(e) { return null; }
        }''')

        if not model_json:
            return None

        model = json.loads(model_json)
        return _model_to_info(model)
    except Exception as exc:
        log.error("Failed to fetch store info from %s: %s", store_url, exc)
        return None
    finally:
        page.close()
        if own_browser:
            browser.close()
            pw_instance.stop()


def _model_to_info(model: dict) -> dict:
    # Fields can be present but explicitly null in ICA's JSON, so `or {}`
    # rather than .get() defaults.
    info: dict = {}

    addr = model.get("address") or {}
    if addr.get("streetAddress"):
        info["address"] = addr["streetAddress"]
    if addr.get("postalCode"):
        info["postal_code"] = addr["postalCode"].replace(" ", "")
    if addr.get("city"):
        info["city"] = addr["city"]

    contact = model.get("contact") or {}
    if contact.get("phoneNumber"):
        info["phone"] = contact["phoneNumber"]

    coords = model.get("coordinates") or {}
    if coords.get("xDecimal"):
        info["latitude"] = float(coords["xDecimal"])
    if coords.get("yDecimal"):
        info["longitude"] = float(coords["yDecimal"])

    if model.get("findUsUrl"):
        info["google_maps_url"] = model["findUsUrl"]

    hours = model.get("openingHours") or {}
    regular = _convert_ica_hours(hours.get("regularOpeningHours") or [])
    special = _convert_ica_hours(hours.get("deviationOpeningHours") or [])

    if regular:
        info["opening_hours"] = json.dumps(regular, ensure_ascii=False)
    if special:
        info["special_hours"] = json.dumps(special, ensure_ascii=False)

    return info


def _convert_ica_hours(entries: list[dict]) -> list[dict]:
    result = []
    for e in entries:
        day_text = e.get("label", "")
        if e.get("isClosed"):
            result.append({"days": _expand_day_label(day_text), "open": None, "close": None})
        else:
            opens = e.get("opens", "")
            closes = e.get("closes", "")
            result.append({
                "days": _expand_day_label(day_text),
                "open": _normalize_time(opens) if opens else None,
                "close": _normalize_time(closes) if closes else None,
            })
    return result


def _expand_day_label(label: str) -> list[str]:
    label = label.replace("–", "-").replace("—", "-").strip()
    if "-" in label:
        start, end = label.split("-", 1)
        s_idx = _day_index(start.strip())
        e_idx = _day_index(end.strip())
        if s_idx is not None and e_idx is not None:
            days = []
            i = s_idx
            while True:
                days.append(SWEDISH_DAYS[i])
                if i == e_idx:
                    break
                i = (i + 1) % 7
            return days
    for day in SWEDISH_DAYS:
        if label.lower() == day.lower():
            return [day]
    return [label]


def _day_index(text: str) -> int | None:
    return DAY_INDEX.get(text.lower())


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
# Deals: fetch & parse from __INITIAL_DATA__
# ---------------------------------------------------------------------------

def _fetch_and_parse_store_deals(deals_url: str, browser=None) -> tuple[list[dict], str | None, int | None]:
    own_browser = browser is None
    pw_instance = None
    if own_browser:
        pw_instance = sync_playwright().start()
        browser = pw_instance.chromium.launch(headless=True)

    page = browser.new_page(user_agent=USER_AGENT)
    try:
        page.goto(deals_url, wait_until="domcontentloaded", timeout=60_000)
        page.wait_for_timeout(2_000)

        raw = page.evaluate('''() => {
            try {
                const d = window.__INITIAL_DATA__;
                const offers = d.offers.weeklyOffers || [];
                const store = d.headerStore && d.headerStore.activeStore || {};
                let flyer = null;
                try {
                    const urls = d.epi.jsonData.storeInfoModel.urls || [];
                    const dr = urls.find(u => u.type === 'DRBlad');
                    if (dr) flyer = dr.url;
                } catch(e) {}
                return JSON.stringify({offers, flyer, storeName: store.name || ''});
            } catch(e) { return null; }
        }''')

        if not raw:
            return [], None, None

        data = json.loads(raw)
        offers = data.get("offers", [])
        flyer_url = data.get("flyer")
        deals = [_offer_to_deal(o, deals_url) for o in offers]
        deals = [d for d in deals if d is not None]

        week_number = _extract_week_number_from_offers(offers)

        return deals, flyer_url, week_number
    except Exception as exc:
        log.error("Failed to fetch deals from %s: %s", deals_url, exc)
        return [], None, None
    finally:
        page.close()
        if own_browser:
            browser.close()
            pw_instance.stop()


def _offer_to_deal(offer: dict, source_url: str) -> dict | None:
    details = offer.get("details", {})
    name = details.get("name", "")
    if not name or len(name) < 2:
        return None

    brand = details.get("brand") or None
    size = details.get("packageInformation") or None
    deal_text = details.get("mechanicInfo") or None
    category = (offer.get("category") or {}).get("articleGroupName")
    restriction = offer.get("restriction") or None
    comparison_price = (offer.get("comparisonPrice") or "").replace(":", ".") or None
    is_membership = "Stammis" in (offer.get("traits") or [])
    valid_to = offer.get("validTo")

    store_info = (offer.get("stores") or [{}])[0] if offer.get("stores") else {}
    original_price = _parse_regular_price(store_info.get("regularPrice"))

    picture = offer.get("picture", {})
    image_url = _build_image_url(picture)

    extra_parts = []
    if restriction:
        extra_parts.append(restriction)
    customer_info = details.get("customerInformation")
    if customer_info:
        extra_parts.append(customer_info)
    if details.get("isSelfScan"):
        extra_parts.append("Gäller vid självscanning")

    eans = [
        {"ean": e["id"], "name": e.get("articleDescription", ""), "image": e.get("image")}
        for e in (offer.get("eans") or [])
        if e.get("id")
    ]

    return {
        "external_id": f"ica:deal:{offer['id']}",
        "name": name,
        "brand": brand,
        "size": size,
        "description": None,
        "category": category,
        "image_url": image_url,
        "original_price": original_price,
        "deal_price": _price_from_text(deal_text),
        "price_label": None,
        "is_membership_price": is_membership,
        "deal_text": deal_text,
        "comparison_price": comparison_price,
        "extra_info": " | ".join(extra_parts) if extra_parts else None,
        "_eans": eans,
    }


def _parse_regular_price(val: str | None) -> float | None:
    if not val:
        return None
    first = val.split("-")[0].strip()
    first = first.replace(",", ".").replace(":", ".")
    try:
        return float(first)
    except ValueError:
        return None


def _build_image_url(picture: dict) -> str | None:
    base = picture.get("baseUrl", "")
    filename = picture.get("fileName", "")
    if not filename:
        return None
    if base:
        return f"{base}/c_lpad,q_auto,f_auto,w_200,h_200/{filename}"
    return f"https://assets.icanet.se/c_lpad,q_auto,f_auto,w_200,h_200/{filename}"


def _price_from_text(deal_text: str | None) -> float | None:
    if not deal_text:
        return None
    m = re.search(r"(\d+(?:[.,]\d+)?)\s*kr", deal_text)
    if m:
        return float(m.group(1).replace(",", "."))
    return None


def _extract_week_number_from_offers(offers: list[dict]) -> int | None:
    if not offers:
        return None
    valid_to = offers[0].get("validTo")
    if valid_to:
        try:
            dt = datetime.fromisoformat(valid_to)
            return dt.isocalendar()[1]
        except ValueError:
            pass
    return None


def _download_flyer(flyer_url: str, store_external_id: str) -> tuple[str | None, int | None]:
    safe_name = re.sub(r"[^a-zA-Z0-9_-]", "_", store_external_id)
    dest = FLYER_DIR / f"{safe_name}.pdf"
    try:
        resp = httpx.get(flyer_url, timeout=60.0, follow_redirects=True, headers={"User-Agent": USER_AGENT})
        resp.raise_for_status()
        content_type = resp.headers.get("content-type", "")
        if "pdf" not in content_type and resp.content[:4] != b"%PDF":
            return None, None
        dest.write_bytes(resp.content)
        return str(dest), len(resp.content)
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


# ---------------------------------------------------------------------------
# Deals: DB persistence
# ---------------------------------------------------------------------------

def _save_deals(db: Session, store: Store, parsed: list[dict]) -> tuple[int, int]:
    parsed = _dedupe(parsed)
    if not parsed:
        return 0, 0

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
        deal.brand = item.get("brand")
        deal.size = item.get("size")
        deal.description = item.get("description")
        deal.image_url = item.get("image_url")
        deal.original_price = item.get("original_price")
        deal.deal_price = item.get("deal_price")
        deal.price_label = item.get("price_label")
        deal.is_membership_price = bool(item.get("is_membership_price"))
        deal.deal_text = item.get("deal_text")
        deal.comparison_price = item.get("comparison_price")
        deal.extra_info = item.get("extra_info")
        deal.source_url = store.weekly_deals_url
        deal.scraped_at = now

    db.commit()

    products_created = _save_products(db, store, parsed)
    return created, products_created


def _save_products(db: Session, store: Store, parsed_deals: list[dict]) -> int:
    all_items: list[dict] = []
    for deal_info in parsed_deals:
        eans = deal_info.get("_eans") or []
        for ean in eans:
            all_items.append({
                "ean": ean["ean"],
                "name": ean["name"],
                "image": ean.get("image"),
                "brand": deal_info.get("brand"),
                "size": deal_info.get("size"),
                "deal_text": deal_info.get("deal_text"),
                "is_membership_price": deal_info.get("is_membership_price", False),
                "comparison_price": deal_info.get("comparison_price"),
            })

    if not all_items:
        return 0

    ext_ids = [f"ica:product:{store.id}:{item['ean']}" for item in all_items]
    existing = {
        p.external_id: p
        for p in db.query(Product).filter(Product.external_id.in_(ext_ids)).all()
    }

    now = datetime.now(timezone.utc)
    created = 0

    for item in all_items:
        ext_id = f"ica:product:{store.id}:{item['ean']}"
        product = existing.get(ext_id)
        if product is None:
            product = Product(
                store_id=store.id,
                external_id=ext_id,
                name=item["name"],
            )
            db.add(product)
            created += 1

        product.name = item["name"]
        product.brand = item.get("brand")
        product.size = item.get("size")
        product.image_url = item.get("image")
        product.deal_text = item.get("deal_text")
        product.is_membership_price = bool(item.get("is_membership_price"))
        product.comparison_price = item.get("comparison_price")
        product.source_url = store.weekly_deals_url
        product.scraped_at = now

    db.commit()
    return created


def _dedupe(items: list[dict]) -> list[dict]:
    seen: dict[str, dict] = {}
    for item in items:
        ext_id = item.get("external_id")
        if ext_id:
            seen[ext_id] = item
    return list(seen.values())
