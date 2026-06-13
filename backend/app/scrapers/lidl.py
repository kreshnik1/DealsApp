from __future__ import annotations

import html as html_lib
import json
import logging
import random
import re
import time
from datetime import datetime, timezone

import httpx
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright
from sqlalchemy.orm import Session

from app.db.models import Company, Deal, Flyer, Store
from app.db.models.store_detail import StoreDetail
from app.dependencies import get_or_create_company

log = logging.getLogger(__name__)

COMPANY_NAME = "Lidl"
COMPANY_SLUG = "lidl"
LIDL_BASE = "https://www.lidl.se"
LIDL_STORES_URL = f"{LIDL_BASE}/s/sv-SE/butiker/"
LIDL_FLYERS_URL = f"{LIDL_BASE}/c/reklamblad/s10018018"
STORE_URL_PREFIX = "/s/sv-SE/butiker/"

# Lidl Sweden runs identical deals and prices in all stores (their region system
# maps every region to the same price list), so deals are scraped once and
# attached to a single anchor store, queryable via chain="LIDL".
CAMPAIGN_LINK_PATTERN = re.compile(r'href="(/c/[a-z0-9-]+/a\d+)"')
GRID_DATA_PATTERN = re.compile(r'data-grid-data="([^"]+)"')

# Polite scraping: fetch a small batch, then pause before the next one.
BATCH_SIZE = 5
REQUEST_DELAY = (1.0, 2.5)
BATCH_PAUSE = (6.0, 12.0)

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

    existing_details = {
        sd.store_id: sd
        for sd in db.query(StoreDetail).filter(
            StoreDetail.store_id.in_([s.id for s in targets])
        ).all()
    }

    log.info("Scraping store info for %d stores (mode=%s, batch_size=%d)", len(targets), mode, BATCH_SIZE)

    now = datetime.now(timezone.utc)
    created = 0
    updated = 0
    unchanged = 0
    failed = 0

    for i, store in enumerate(targets):
        _throttle(i)

        try:
            info = _fetch_store_info(store.store_url)
        except Exception as exc:
            log.error("Unexpected error scraping store '%s' (id=%d): %s", store.name, store.id, exc)
            failed += 1
            continue

        if not info:
            log.error("No data scraped for store '%s' (id=%d): %s", store.name, store.id, store.store_url)
            failed += 1
            continue

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

        if (i + 1) % BATCH_SIZE == 0:
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
# Public API — deals (national: scraped once, stored on an anchor store)
# ---------------------------------------------------------------------------

def scrape_company_store_deals(db: Session, company_id: int) -> dict:
    company = db.query(Company).filter(Company.id == company_id).first()
    if company is None:
        raise ValueError(f"Company {company_id} not found")

    anchor = (
        db.query(Store)
        .filter(Store.company_id == company_id)
        .order_by(Store.id)
        .first()
    )
    if anchor is None:
        raise ValueError("No Lidl stores found — run /scrape/lidl/stores first")

    pages = _discover_campaign_pages()
    deals: dict[str, dict] = {}
    pages_scraped = 0

    for i, page_url in enumerate(pages):
        _throttle(i)
        page_deals = _fetch_campaign_deals(page_url)
        if page_deals is None:
            continue
        pages_scraped += 1
        for deal in page_deals:
            deals.setdefault(deal["external_id"], deal)

    created = _save_deals(db, anchor, list(deals.values()))

    flyers_data = _fetch_current_flyers()
    flyers_created = sum(1 for fl in flyers_data if _save_flyer(db, anchor, fl))

    return {
        "company_id": company.id,
        "company_name": company.name,
        "national_deals": True,
        "anchor_store_id": anchor.id,
        "campaign_pages_found": len(pages),
        "campaign_pages_scraped": pages_scraped,
        "deals_found": len(deals),
        "deals_created": created,
        "flyers_found": len(flyers_data),
        "flyers_created": flyers_created,
    }


def scrape_store_deals(db: Session, company_id: int, store_id: int) -> dict:
    store = db.query(Store).filter(
        Store.company_id == company_id, Store.id == store_id
    ).first()
    if store is None:
        raise ValueError(f"Store {store_id} not found for company {company_id}")

    # Lidl deals are identical in every store, so a per-store scrape is the
    # national scrape.
    return scrape_company_store_deals(db, company_id)


def scrape_first_store_deals(db: Session) -> dict:
    company = db.query(Company).filter(Company.slug == COMPANY_SLUG).first()
    if company is None:
        raise ValueError("Lidl company not found")
    return scrape_company_store_deals(db, company.id)


# ---------------------------------------------------------------------------
# Deals: campaign page discovery & parsing
# ---------------------------------------------------------------------------

def _throttle(index: int) -> None:
    if index == 0:
        return
    if index % BATCH_SIZE == 0:
        pause = random.uniform(*BATCH_PAUSE)
        log.info("Batch of %d done (%d requests so far), pausing %.1fs", BATCH_SIZE, index, pause)
        time.sleep(pause)
    else:
        time.sleep(random.uniform(*REQUEST_DELAY))


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


def _discover_campaign_pages() -> list[str]:
    html = _fetch_html(f"{LIDL_BASE}/")
    if not html:
        raise ValueError("Could not fetch Lidl homepage to discover campaign pages")

    hrefs = sorted(set(CAMPAIGN_LINK_PATTERN.findall(html)))
    pages = [f"{LIDL_BASE}{href}" for href in hrefs]
    log.info("Discovered %d Lidl campaign pages", len(pages))
    return pages


def _fetch_campaign_deals(page_url: str) -> list[dict] | None:
    html = _fetch_html(page_url)
    if not html:
        return None

    category = _extract_page_title(html)
    deals = []
    for blob in GRID_DATA_PATTERN.findall(html):
        try:
            tile = json.loads(html_lib.unescape(blob))
            deal = _tile_to_deal(tile, category, page_url)
        except (ValueError, TypeError, AttributeError, KeyError) as exc:
            log.warning("Skipping malformed product tile on %s: %s", page_url, exc)
            continue
        if deal:
            deals.append(deal)

    log.info("Campaign page '%s': %d deals — %s", category or "?", len(deals), page_url)
    return deals


def _extract_page_title(html: str) -> str | None:
    m = re.search(r"<title>([^<]+)</title>", html)
    if not m:
        return None
    return html_lib.unescape(m.group(1)).split("|")[0].strip() or None


def _tile_to_deal(tile: dict, category: str | None, page_url: str) -> dict | None:
    product_id = tile.get("productId")
    name = tile.get("title") or tile.get("fullTitle")
    if not product_id or not name:
        return None

    region = (tile.get("regionsPrices") or {}).get("1") or {}
    price_node = None
    is_membership = False
    if isinstance(region.get("currentPrice"), dict):
        price_node = region["currentPrice"]
    elif isinstance(region.get("currentLidlPlusPrice"), dict):
        price_node = region["currentLidlPlusPrice"].get("price")
        is_membership = True
    if not isinstance(price_node, dict):
        price_node = tile.get("price") if isinstance(tile.get("price"), dict) else None

    if not price_node:
        return None

    deal_price = price_node.get("price")
    discount = price_node.get("discount") or {}
    original_price = price_node.get("oldPrice") or discount.get("deletedPrice")
    deal_text = discount.get("discountText")
    valid_to = _parse_iso(price_node.get("endDate"))

    # Only time-bounded or discounted prices are deals; skip evergreen assortment.
    if deal_price is None or (original_price is None and not deal_text and valid_to is None):
        return None

    brand = tile.get("brand") or {}
    brand_name = brand.get("name") if brand.get("showBrand") else None

    image = tile.get("image")
    if not image:
        image_list = tile.get("imageList_V1") or []
        image = image_list[0].get("image") if image_list else None

    keyfacts = tile.get("keyfacts") or {}
    description = _strip_html(keyfacts.get("description"))

    canonical = tile.get("canonicalUrl")
    source_url = f"{LIDL_BASE}{canonical}" if canonical else page_url

    return {
        "external_id": f"lidl:deal:{product_id}",
        "name": name,
        "brand": brand_name,
        "size": (price_node.get("packaging") or {}).get("text"),
        "description": description,
        "category": category,
        "image_url": image,
        "original_price": float(original_price) if original_price is not None else None,
        "deal_price": float(deal_price),
        "deal_text": deal_text,
        "is_membership_price": is_membership,
        "comparison_price": (price_node.get("basePrice") or {}).get("text"),
        "valid_from": _parse_iso(price_node.get("startDate")),
        "valid_to": valid_to,
        "source_url": source_url,
    }


def _strip_html(value: str | None) -> str | None:
    if not value:
        return None
    text = re.sub(r"<[^>]+>", " ", html_lib.unescape(value))
    return " ".join(text.split()) or None


def _parse_iso(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _save_deals(db: Session, store: Store, parsed: list[dict]) -> int:
    if not parsed:
        return 0

    ext_ids = [p["external_id"] for p in parsed]
    existing = {
        d.external_id: d
        for d in db.query(Deal).filter(Deal.external_id.in_(ext_ids)).all()
    }

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
        deal.category = item["category"]
        deal.image_url = item["image_url"]
        deal.original_price = item["original_price"]
        deal.deal_price = item["deal_price"]
        deal.deal_text = item["deal_text"]
        deal.is_membership_price = bool(item["is_membership_price"])
        deal.comparison_price = item["comparison_price"]
        deal.valid_from = item["valid_from"]
        deal.valid_to = item["valid_to"]
        deal.source_url = item["source_url"]
        deal.scraped_at = now

    db.commit()
    return created


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
# Store info: fetch & parse
# ---------------------------------------------------------------------------

def _fetch_store_info(store_url: str) -> dict | None:
    html = _fetch_html(store_url)
    if html:
        info = _parse_store_page(BeautifulSoup(html, "lxml"))
        if info:
            return info

    log.info("Static fetch failed, falling back to browser: %s", store_url)
    html = _fetch_with_browser(store_url)
    if not html:
        return None
    return _parse_store_page(BeautifulSoup(html, "lxml"))


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
