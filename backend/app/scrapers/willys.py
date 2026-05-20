import logging
from datetime import datetime, timezone

from playwright.sync_api import sync_playwright
from sqlalchemy.orm import Session

from app.db.models import Deal, Store
from app.dependencies import get_or_create_company

log = logging.getLogger(__name__)

CHAIN = "Willys"
COMPANY_SLUG = "willys"
OFFERS_URL = "https://www.willys.se/erbjudanden/butik"

USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)

COOKIE_SELECTORS = [
    "button[data-testid='cookie-accept']",
    "#onetrust-accept-btn-handler",
    "button:has-text('Acceptera')",
    "button:has-text('Godkänn')",
    "button:has-text('Acceptera alla')",
    "[class*='cookie'] button",
    "[id*='cookie'] button",
]


def scrape(db: Session, lat: float, lon: float) -> int:
    log.info("Starting Willys scrape at lat=%s lon=%s", lat, lon)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            geolocation={"latitude": lat, "longitude": lon},
            permissions=["geolocation"],
            locale="sv-SE",
            extra_http_headers={"Accept-Language": "sv-SE,sv;q=0.9"},
            user_agent=USER_AGENT,
        )
        page = context.new_page()
        page.goto(OFFERS_URL, wait_until="domcontentloaded", timeout=30_000)

        _dismiss_cookie_banner(page)

        try:
            page.wait_for_selector(
                "[data-testid='offer-card'], .product-card, article[class*='offer']",
                timeout=20_000,
            )
        except Exception:
            log.warning("Offer cards not found — page may require manual store selection")
            browser.close()
            return 0

        store_name = _read_store_name(page)
        cards = page.query_selector_all(
            "[data-testid='offer-card'], article[class*='offer'], article[class*='product']"
        )
        log.info("Found %d offer cards for store: %s", len(cards), store_name)

        if not cards:
            browser.close()
            return 0

        store_ext_id = f"willys_{store_name.lower().replace(' ', '_')}"
        store = _get_or_create_store(db, store_name, store_ext_id)
        now = datetime.now(timezone.utc)
        saved = 0

        for card in cards:
            try:
                name = _text(card, "[data-testid='offer-name'], .product-name, h2, h3")
                if not name:
                    continue

                ext_id = card.get_attribute("data-product-id") or card.get_attribute("id") or ""
                deal = db.query(Deal).filter_by(chain=CHAIN, external_id=ext_id).first() if ext_id else None
                if deal is None:
                    deal = Deal(chain=CHAIN, store_id=store.id, external_id=ext_id or None)
                    db.add(deal)

                deal.name = name
                deal.brand = _text(card, "[data-testid='offer-brand'], .brand")
                deal.price_label = _text(card, "[data-testid='offer-price-label'], .price-splash, .offer-label")
                deal.deal_price = _parse_price(_text(card, "[data-testid='offer-price'], .price, .deal-price"))
                deal.original_price = _parse_price(_text(card, "[data-testid='original-price'], .original-price, .ordinary-price"))
                deal.comparison_price = _text(card, "[data-testid='comparison-price'], .comparison-price, .jfr-price")
                deal.image_url = _attr(card, "img", "src")
                deal.scraped_at = now
                deal.source_url = OFFERS_URL
                saved += 1
            except Exception as exc:
                log.warning("Failed to parse card: %s", exc)

        browser.close()

    db.commit()
    log.info("Willys scrape complete: %d deals saved", saved)
    return saved


def _dismiss_cookie_banner(page) -> None:
    for selector in COOKIE_SELECTORS:
        try:
            page.click(selector, timeout=3_000)
            page.wait_for_timeout(1_000)
            return
        except Exception:
            continue


def _read_store_name(page) -> str:
    try:
        el = page.query_selector("[data-testid='store-name'], .store-name, h1")
        if el:
            name = el.inner_text().strip()
            if name:
                return name
    except Exception:
        pass
    return CHAIN


def _get_or_create_store(db: Session, name: str, external_id: str) -> Store:
    company = get_or_create_company(db, CHAIN, COMPANY_SLUG)
    store = db.query(Store).filter_by(chain=CHAIN, external_id=external_id).first()
    if store is None:
        store = Store(company_id=company.id, name=name, chain=CHAIN, external_id=external_id)
        db.add(store)
        db.flush()
    else:
        store.company_id = company.id
        if store.name != name:
            store.name = name
    return store


def _parse_price(text: str | None) -> float | None:
    if not text:
        return None
    try:
        return float(text.replace("kr", "").replace(":-", "").replace(",", ".").replace("\xa0", "").strip())
    except ValueError:
        return None


def _text(el, selector: str) -> str | None:
    for sel in selector.split(","):
        try:
            found = el.query_selector(sel.strip())
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
