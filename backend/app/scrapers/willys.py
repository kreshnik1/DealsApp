"""
Willys scraper using Playwright.

Flow:
  1. Launch Chromium with spoofed geolocation (lat/lon from caller)
  2. Navigate to /erbjudanden/butik — Willys auto-selects the nearest store
  3. Wait for offer cards to render
  4. Extract product data and upsert into DB
"""

import logging
from datetime import datetime

from playwright.sync_api import sync_playwright
from sqlalchemy.orm import Session

from app.db.models import Company, Deal, Store

log = logging.getLogger(__name__)

CHAIN = "Willys"
COMPANY_SLUG = "willys"
OFFERS_URL = "https://www.willys.se/erbjudanden/butik"

HEADERS = {
    "Accept-Language": "sv-SE,sv;q=0.9",
}


def _get_or_create_store(db: Session, name: str, external_id: str) -> Store:
    company = _get_or_create_company(db)
    store = db.query(Store).filter_by(chain=CHAIN, external_id=external_id).first()
    if not store:
        store = Store(
            company_id=company.id,
            name=name,
            chain=CHAIN,
            external_id=external_id,
        )
        db.add(store)
        db.flush()
    else:
        store.company_id = company.id
    if store.name != name:
        store.name = name
    return store


def _get_or_create_company(db: Session) -> Company:
    company = db.query(Company).filter_by(slug=COMPANY_SLUG).first()
    if not company:
        company = Company(name=CHAIN, slug=COMPANY_SLUG)
        db.add(company)
        db.flush()
    return company


def _parse_price(text: str | None) -> float | None:
    if not text:
        return None
    try:
        return float(
            text.replace("kr", "")
                .replace(":-", "")
                .replace(",", ".")
                .replace("\xa0", "")
                .strip()
        )
    except ValueError:
        return None


def scrape(db: Session, lat: float, lon: float) -> int:
    """
    Scrape Willys offers for the store nearest to (lat, lon).
    Returns number of deals saved.
    """
    log.info("Starting Willys scrape at lat=%s lon=%s", lat, lon)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            geolocation={"latitude": lat, "longitude": lon},
            permissions=["geolocation"],
            locale="sv-SE",
            extra_http_headers=HEADERS,
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
        )
        page = context.new_page()

        page.goto(OFFERS_URL, wait_until="domcontentloaded", timeout=30_000)

        # Accept cookie/consent banner — try multiple known selectors
        for selector in [
            "button[data-testid='cookie-accept']",
            "#onetrust-accept-btn-handler",
            "button:has-text('Acceptera')",
            "button:has-text('Godkänn')",
            "button:has-text('Acceptera alla')",
            "[class*='cookie'] button",
            "[id*='cookie'] button",
        ]:
            try:
                page.click(selector, timeout=3_000)
                page.wait_for_timeout(1_000)
                break
            except Exception:
                continue

        # Wait for offer cards to appear
        try:
            page.wait_for_selector("[data-testid='offer-card'], .product-card, article[class*='offer']", timeout=20_000)
        except Exception:
            log.warning("Offer cards not found — page may require manual store selection")
            browser.close()
            return 0

        # Get store name from page
        store_name = CHAIN
        try:
            store_el = page.query_selector("[data-testid='store-name'], .store-name, h1")
            if store_el:
                store_name = store_el.inner_text().strip() or CHAIN
        except Exception:
            pass

        # Extract all offer cards
        cards = page.query_selector_all(
            "[data-testid='offer-card'], article[class*='offer'], article[class*='product']"
        )
        log.info("Found %d offer cards for store: %s", len(cards), store_name)

        if not cards:
            browser.close()
            return 0

        store_ext_id = f"willys_{store_name.lower().replace(' ', '_')}"
        store = _get_or_create_store(db, store_name, store_ext_id)
        now = datetime.utcnow()
        saved = 0

        for card in cards:
            try:
                name = _text(card, "[data-testid='offer-name'], .product-name, h2, h3")
                if not name:
                    continue

                brand = _text(card, "[data-testid='offer-brand'], .brand")
                price_label = _text(card, "[data-testid='offer-price-label'], .price-splash, .offer-label")
                deal_price_raw = _text(card, "[data-testid='offer-price'], .price, .deal-price")
                original_price_raw = _text(card, "[data-testid='original-price'], .original-price, .ordinary-price")
                comparison_price = _text(card, "[data-testid='comparison-price'], .comparison-price, .jfr-price")
                image_url = _attr(card, "img", "src")
                ext_id = card.get_attribute("data-product-id") or card.get_attribute("id") or ""

                deal = (
                    db.query(Deal).filter_by(chain=CHAIN, external_id=ext_id).first()
                    if ext_id
                    else None
                )
                if deal is None:
                    deal = Deal(chain=CHAIN, store_id=store.id, external_id=ext_id or None)
                    db.add(deal)

                deal.name = name
                deal.brand = brand
                deal.price_label = price_label
                deal.deal_price = _parse_price(deal_price_raw)
                deal.original_price = _parse_price(original_price_raw)
                deal.comparison_price = comparison_price
                deal.image_url = image_url
                deal.scraped_at = now
                deal.source_url = OFFERS_URL

                saved += 1

            except Exception as exc:
                log.warning("Failed to parse card: %s", exc)
                continue

        browser.close()

    db.commit()
    log.info("Willys scrape complete: %d deals saved", saved)
    return saved


def _text(el, selector: str) -> str | None:
    """Try each comma-separated selector, return first match text."""
    for sel in selector.split(","):
        sel = sel.strip()
        try:
            found = el.query_selector(sel)
            if found:
                t = found.inner_text().strip()
                if t:
                    return t
        except Exception:
            continue
    return None


def _attr(el, selector: str, attr: str) -> str | None:
    try:
        found = el.query_selector(selector)
        return found.get_attribute(attr) if found else None
    except Exception:
        return None
