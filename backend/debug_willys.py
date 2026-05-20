"""Run with: python debug_willys.py"""
from playwright.sync_api import sync_playwright

LAT = 56.8790
LON = 14.8059

with sync_playwright() as p:
    browser = p.chromium.launch(headless=False)
    context = browser.new_context(
        geolocation={"latitude": LAT, "longitude": LON},
        permissions=["geolocation"],
        locale="sv-SE",
        user_agent=(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/120.0.0.0 Safari/537.36"
        ),
    )
    page = context.new_page()
    page.goto("https://www.willys.se/erbjudanden/butik", wait_until="networkidle", timeout=30_000)

    # Accept cookie banner
    for selector in [
        "#onetrust-accept-btn-handler",
        "button:has-text('Acceptera alla')",
        "button:has-text('Acceptera')",
        "button:has-text('Godkänn')",
    ]:
        try:
            page.click(selector, timeout=3_000)
            print(f"Clicked cookie: {selector}")
            page.wait_for_timeout(1_000)
            break
        except Exception:
            continue

    # Click store/delivery picker
    try:
        page.click("[data-testid='delivery-picker-toggle']", timeout=5_000)
        print("Clicked delivery picker")
        page.wait_for_timeout(2_000)

        # Print what's inside the picker
        picker = page.query_selector("[data-testid='delivery-picker'], [class*='store-picker'], [class*='StorePicker']")
        if picker:
            print("Picker HTML:", picker.inner_html()[:1000])
    except Exception as e:
        print("Could not click delivery picker:", e)

    # Wait for skeletons to disappear
    try:
        page.wait_for_selector("[data-testid='skeleton-rect']", state="hidden", timeout=10_000)
        print("Skeletons gone")
    except Exception:
        print("Skeletons still present or not found")

    page.wait_for_timeout(3_000)

    # Check what's in the grid
    grid = page.query_selector("[data-testid='grid']")
    if grid:
        children = grid.query_selector_all(":scope > *")
        print(f"\nGrid has {len(children)} children")
        for i, child in enumerate(children[:3]):
            print(f"\n--- Grid child {i} ---")
            print("tag:", child.evaluate("el => el.tagName"))
            print("class:", child.get_attribute("class"))
            print("data-testid:", child.get_attribute("data-testid"))
            print("text:", child.inner_text()[:150])

    # Save rendered HTML
    html = page.content()
    with open("/tmp/willys_rendered.html", "w") as f:
        f.write(html)
    print("\nHTML saved to /tmp/willys_rendered.html")

    input("\nPress Enter to close...")
    browser.close()
