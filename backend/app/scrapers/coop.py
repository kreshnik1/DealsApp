from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import hashlib
import re
from urllib.parse import urljoin
from xml.etree import ElementTree

from bs4 import BeautifulSoup
import httpx
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
from playwright.sync_api import sync_playwright
from sqlalchemy.orm import Session

from app.db.models import Company, Product, Store

COMPANY_NAME = "Coop"
COMPANY_SLUG = "coop"
COOP_SITEMAP_URL = "https://www.coop.se/sitemap_pages.xml"
COOP_STORE_PREFIX = "https://www.coop.se/butiker-erbjudanden/"


@dataclass(slots=True)
class CoopStoreLink:
    name: str
    concept: str
    slug: str
    store_url: str


def discover_store_links() -> list[CoopStoreLink]:
    response = httpx.get(COOP_SITEMAP_URL, timeout=30.0)
    response.raise_for_status()

    root = ElementTree.fromstring(response.text)
    namespace = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    seen: set[str] = set()
    stores: list[CoopStoreLink] = []

    for loc in root.findall("sm:url/sm:loc", namespace):
        url = (loc.text or "").strip()
        if not url.startswith(COOP_STORE_PREFIX):
            continue
        if url in seen:
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

    stores.sort(key=lambda store: (store.concept, store.name))
    return stores


def save_store_links(db: Session) -> int:
    company = _get_or_create_company(db)
    stores = discover_store_links()
    saved = 0

    for item in stores:
        external_id = _store_external_id(item.concept, item.slug)
        store = db.query(Store).filter_by(external_id=external_id).first()
        if store is None:
            store = Store(
                company_id=company.id,
                name=item.name,
                chain=item.concept.upper(),
                external_id=external_id,
            )
            db.add(store)
            saved += 1

        store.company_id = company.id
        store.name = item.name
        store.chain = item.concept.upper()
        store.store_url = item.store_url
        store.weekly_deals_url = None

    db.commit()
    return saved


def scrape_first_store_products(db: Session) -> dict[str, int | str]:
    store = (
        db.query(Store)
        .join(Company, Store.company_id == Company.id)
        .filter(Company.slug == COMPANY_SLUG)
        .order_by(Store.id.asc())
        .first()
    )
    if store is None or not store.store_url:
        raise ValueError("No Coop store with store_url found")

    parsed_products = _fetch_and_parse_store_products(store.store_url)
    created = _save_products(db, store, parsed_products)
    return {
        "store_id": store.id,
        "store_name": store.name,
        "products_found": len(parsed_products),
        "products_created": created,
    }


def scrape_company_store_products(db: Session, company_id: int) -> dict[str, int | str]:
    company = db.query(Company).filter(Company.id == company_id).first()
    if company is None:
        raise ValueError(f"Company {company_id} not found")

    stores = (
        db.query(Store)
        .filter(Store.company_id == company_id)
        .order_by(Store.id.asc())
        .all()
    )

    totals = {
        "company_id": company.id,
        "company_name": company.name,
        "stores_checked": 0,
        "stores_with_products": 0,
        "products_found": 0,
        "products_created": 0,
    }

    for store in stores:
        if not store.store_url:
            continue

        totals["stores_checked"] += 1
        parsed_products = _fetch_and_parse_store_products(store.store_url)
        if not parsed_products:
            continue

        totals["stores_with_products"] += 1
        totals["products_found"] += len(parsed_products)
        totals["products_created"] += _save_products(db, store, parsed_products)

    return totals


def scrape_store_products(db: Session, company_id: int, store_id: int) -> dict[str, int | str]:
    company = db.query(Company).filter(Company.id == company_id).first()
    if company is None:
        raise ValueError(f"Company {company_id} not found")

    store = (
        db.query(Store)
        .filter(Store.company_id == company_id, Store.id == store_id)
        .first()
    )
    if store is None:
        raise ValueError(f"Store {store_id} not found for company {company_id}")
    if not store.store_url:
        raise ValueError(f"Store {store_id} has no store_url")

    parsed_products = _fetch_and_parse_store_products(store.store_url)
    created = _save_products(db, store, parsed_products)

    return {
        "company_id": company.id,
        "company_name": company.name,
        "store_id": store.id,
        "store_name": store.name,
        "products_found": len(parsed_products),
        "products_created": created,
    }


def _parse_store_url(url: str) -> tuple[str, str] | None:
    path = url.removeprefix(COOP_STORE_PREFIX).strip("/")
    parts = [part for part in path.split("/") if part]
    if len(parts) != 2:
        return None
    return parts[0], parts[1]


def _humanize_slug(slug: str) -> str:
    cleaned = " ".join(part for part in slug.replace("-", " ").split() if part)
    return cleaned.title()


def _get_or_create_company(db: Session) -> Company:
    company = db.query(Company).filter_by(slug=COMPANY_SLUG).first()
    if company is None:
        company = Company(name=COMPANY_NAME, slug=COMPANY_SLUG)
        db.add(company)
        db.flush()
    return company


def _store_external_id(concept: str, slug: str) -> str:
    return f"{COMPANY_SLUG}:{concept}:{slug}"


def _parse_products_from_html(html: str, source_url: str) -> list[dict[str, str | None]]:
    soup = BeautifulSoup(html, "lxml")
    items: list[dict[str, str | None]] = []

    for article in soup.select("li.Grid-cell article"):
        name_el = article.select_one("h3")
        if name_el is None:
            continue

        name = _clean_text(name_el.get_text(" ", strip=True))
        if not name:
            continue

        meta_rows = article.select("div.uLmN8HjX")
        brand = None
        size = None
        description = None

        if meta_rows:
            spans = meta_rows[0].find_all("span")
            if spans:
                brand = _clean_text(spans[0].get_text(" ", strip=True)).rstrip(".")
            if len(spans) > 1:
                size = _clean_text(spans[1].get_text(" ", strip=True))

        if len(meta_rows) > 1:
            description = _clean_text(meta_rows[1].get_text(" ", strip=True))

        image_el = article.select_one("img")
        image_url = None
        if image_el is not None:
            image_url = image_el.get("src") or image_el.get("srcset", "").split(" ")[0]
            if image_url:
                image_url = urljoin("https:", image_url) if image_url.startswith("//") else image_url

        price_label = _extract_price_label(article)
        is_membership_price = _is_membership_price(price_label, article)
        deal_text = _normalize_deal_text(
            _clean_text(
            " ".join(span.get_text(" ", strip=True) for span in article.select("div.slH8Imgo span"))
            )
        )
        aria_button = article.select_one("button[aria-label]")
        aria_label = aria_button.get("aria-label", "") if aria_button is not None else ""
        if not deal_text:
            deal_text = _normalize_deal_text(_extract_deal_text_from_aria_label(aria_label))

        extra_bits = [
            _clean_text(node.get_text(" ", strip=True))
            for node in article.select("div.UWFn16pY div")
            if _clean_text(node.get_text(" ", strip=True))
        ]
        extra_info = " | ".join(extra_bits) if extra_bits else None

        comparison_price = None
        if extra_bits:
            for bit in extra_bits:
                if _looks_like_comparison_price(bit):
                    comparison_price = bit
                    break

        if comparison_price is None and aria_button is not None:
            comparison_price = _extract_comparison_price_from_aria_label(aria_label)

        external_id = _product_external_id(source_url, name, brand, size, deal_text)
        items.append(
            {
                "external_id": external_id,
                "name": name,
                "brand": brand,
                "size": size,
                "description": description,
                "image_url": image_url,
                "price_label": price_label,
                "is_membership_price": is_membership_price,
                "deal_text": deal_text or None,
                "comparison_price": comparison_price,
                "extra_info": extra_info,
            }
        )

    return items


def _clean_text(value: str | None) -> str:
    if not value:
        return ""
    return " ".join(value.split())


def _extract_price_label(article) -> str | None:
    for node in article.find_all("div"):
        text = _clean_text(node.get_text(" ", strip=True))
        if text and text.upper() == text and len(text) <= 20 and "KR" not in text:
            if any(word in text for word in ["MEDLEMSPRIS", "PRIS"]):
                return text
    return None


def _extract_from_aria_label(value: str, marker: str) -> str | None:
    if marker not in value:
        return None
    tail = value.split(marker, 1)[1].strip(" ,")
    return tail or None


def _extract_deal_text_from_aria_label(value: str) -> str | None:
    if not value:
        return None

    segments = [_clean_text(segment) for segment in value.split(",")]
    for segment in segments:
        lowered = segment.lower()
        if any(token in lowered for token in [" för ", " for ", "/kg", "/ pc", "/pc", " per ", "/ mix"]):
            return segment
    return None


def _normalize_deal_text(value: str | None) -> str | None:
    if not value:
        return None

    normalized = _clean_text(value)
    normalized = re.sub(r"\b(kr)(?:\s+\1\b)+", r"\1", normalized, flags=re.IGNORECASE)
    normalized = re.sub(r"(/ ?[A-Za-z]+)(?:\s+\1\b)+", r"\1", normalized, flags=re.IGNORECASE)
    normalized = normalized.replace("kr / kg", "kr/kg")
    normalized = normalized.replace("kr / pc", "kr/pc")
    normalized = normalized.replace("kr / st", "kr/st")
    return normalized or None


def _extract_comparison_price_from_aria_label(value: str) -> str | None:
    if not value:
        return None

    segments = [_clean_text(segment) for segment in value.split(",")]
    for segment in segments:
        if _looks_like_comparison_price(segment):
            return segment

    for marker in ["Jämförpris", "Compare price", "Comparison price"]:
        extracted = _extract_from_aria_label(value, marker)
        if extracted:
            return extracted
    return None


def _looks_like_comparison_price(value: str) -> bool:
    lowered = value.lower()
    return any(token in lowered for token in ["jfr-pris", "jämförpris", "compare price", "comparison price"])


def _is_membership_price(price_label: str | None, article) -> bool:
    candidates = [price_label or ""]

    aria_button = article.select_one("button[aria-label]")
    if aria_button is not None:
        candidates.append(aria_button.get("aria-label", ""))

    article_text = _clean_text(article.get_text(" ", strip=True))
    candidates.append(article_text)

    needles = [
        "medlemspris",
        "membership price",
        "member price",
    ]
    lowered = " | ".join(candidates).lower()
    return any(needle in lowered for needle in needles)


def _product_external_id(
    source_url: str,
    name: str,
    brand: str | None,
    size: str | None,
    deal_text: str | None,
) -> str:
    raw = "|".join([source_url, name, brand or "", size or "", deal_text or ""])
    digest = hashlib.sha1(raw.encode("utf-8")).hexdigest()
    return f"{COMPANY_SLUG}:product:{digest}"


def _fetch_and_parse_store_products(store_url: str) -> list[dict[str, str | None]]:
    html = _fetch_store_html(store_url)
    return _parse_products_from_html(html, store_url)


def _fetch_store_html(store_url: str) -> str:
    response = httpx.get(
        store_url,
        timeout=30.0,
        follow_redirects=True,
        headers={"User-Agent": _browser_user_agent()},
    )
    response.raise_for_status()
    html = response.text
    if _html_contains_product_cards(html) and not _html_contains_offer_dialog_buttons(html):
        return html

    return _fetch_store_html_with_browser(store_url)


def _fetch_store_html_with_browser(store_url: str) -> str:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page(user_agent=_browser_user_agent())
        try:
            page.goto(store_url, wait_until="domcontentloaded", timeout=60_000)
            try:
                page.wait_for_selector(
                    "li.Grid-cell article, article.ohKiwh8z",
                    timeout=12_000,
                )
            except PlaywrightTimeoutError:
                # Some store pages never render deals; keep the final DOM so we can parse and skip cleanly.
                pass
            dialog_html = _collect_offer_dialog_html(page)
            page.wait_for_timeout(1_500)
            return page.content() + "\n" + dialog_html
        finally:
            page.close()
            browser.close()


def _collect_offer_dialog_html(page) -> str:
    dialog_fragments: list[str] = []
    buttons = page.locator("button").filter(
        has_text=re.compile(r"^(See|Se)\s+\d+\s+(items|varor)$", re.IGNORECASE)
    )
    count = buttons.count()

    for index in range(count):
        button = buttons.nth(index)
        visible_label = _clean_text(button.text_content() or "")
        if not _is_offer_dialog_button(visible_label):
            continue

        try:
            button.scroll_into_view_if_needed(timeout=3_000)
            button.evaluate("element => element.click()")
            page.wait_for_selector(
                "div._111YdG_DialogContainer h1, div._111YdG_DialogContainer article.ohKiwh8z",
                timeout=6_000,
            )
            dialog = page.locator("div._111YdG_DialogContainer").last
            dialog_fragments.append(dialog.inner_html(timeout=3_000))
            close_button = dialog.locator("button.CM0Nmq_Button--icon").first
            close_button.click(timeout=5_000, force=True)
            page.wait_for_timeout(150)
        except PlaywrightTimeoutError:
            continue
        except Exception:
            continue

    return "\n".join(dialog_fragments)


def _is_offer_dialog_button(label: str) -> bool:
    lowered = label.lower()
    return (
        any(token in lowered for token in ["see ", "se "])
        and any(token in lowered for token in [" items", " varor"])
    )


def _html_contains_offer_dialog_buttons(html: str) -> bool:
    markers = (
        "See 2 items",
        "See 3 items",
        "See 4 items",
        "Se 2 varor",
        "Se 3 varor",
        "Se 4 varor",
    )
    return any(marker in html for marker in markers)


def _html_contains_product_cards(html: str) -> bool:
    markers = (
        "li class=\"Grid-cell",
        "class=\"ohKiwh8z",
        "containerclassname=\"ha6aAK6g\"",
        "class=\"slH8Imgo\"",
    )
    return any(marker in html for marker in markers)


def _browser_user_agent() -> str:
    return (
        "Mozilla/5.0 (X11; Linux x86_64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/133.0.0.0 Safari/537.36"
    )


def _save_products(
    db: Session,
    store: Store,
    parsed_products: list[dict[str, str | None]],
) -> int:
    parsed_products = _dedupe_products(parsed_products)
    created = 0

    for item in parsed_products:
        product = db.query(Product).filter_by(external_id=item["external_id"]).first()
        if product is None:
            product = Product(
                store_id=store.id,
                external_id=item["external_id"],
                name=item["name"],
            )
            db.add(product)
            created += 1

        product.store_id = store.id
        product.name = item["name"]
        product.brand = item["brand"]
        product.size = item["size"]
        product.description = item["description"]
        product.image_url = item["image_url"]
        product.price_label = item["price_label"]
        product.is_membership_price = bool(item["is_membership_price"])
        product.deal_text = item["deal_text"]
        product.comparison_price = item["comparison_price"]
        product.extra_info = item["extra_info"]
        product.source_url = store.store_url
        product.scraped_at = datetime.utcnow()

    db.commit()
    return created


def _dedupe_products(
    parsed_products: list[dict[str, str | None]],
) -> list[dict[str, str | None]]:
    deduped: dict[str, dict[str, str | None]] = {}

    for item in parsed_products:
        external_id = item["external_id"]
        if not external_id:
            continue
        deduped[external_id] = item

    return list(deduped.values())
