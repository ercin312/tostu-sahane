import json
import re
import urllib.request
from html import unescape

UA = {"User-Agent": "Mozilla/5.0"}


def fetch_json(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def fetch_text(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", errors="ignore")


def strip_html(s):
    s = re.sub(r"<[^>]+>", " ", s or "")
    return unescape(re.sub(r"\s+", " ", s)).strip()


def parse_price_from_html(html):
    # WooCommerce variable product variations embedded in page
    m = re.search(r'data-product_variations="(\[.*?\])"', html)
    if m:
        try:
            raw = m.group(1).replace("&quot;", '"').replace("&amp;", "&")
            variations = json.loads(raw)
            prices = [
                float(v["display_price"])
                for v in variations
                if v.get("display_price") not in (None, "", "0")
            ]
            if prices:
                return min(prices)
        except (json.JSONDecodeError, KeyError, ValueError):
            pass

    amounts = re.findall(r'"display_price":\s*([0-9.]+)', html)
    if amounts:
        return min(float(a) for a in amounts)

    patterns = [
        r'class="woocommerce-Price-amount[^"]*"[^>]*>\s*<bdi>\s*([0-9]+[.,][0-9]{2})',
        r'woocommerce-Price-amount amount[^>]*>.*?([0-9]+[.,][0-9]{2})',
    ]
    for p in patterns:
        m = re.search(p, html, re.S)
        if m:
            return float(m.group(1).replace(",", "."))
    return None


def main():
    products = []
    page = 1
    while page <= 10:
        url = (
            "https://www.tostusahane.com/wp-json/wc/store/products"
            f"?per_page=100&page={page}"
        )
        try:
            batch = fetch_json(url)
        except Exception:
            break
        if not batch:
            break
        products.extend(batch)
        page += 1

    print(f"store_api_count={len(products)}")

    out = []
    for p in products:
        slug = p["slug"]
        permalink = p["permalink"]
        cats = [c["name"] for c in p.get("categories", [])]
        img = p["images"][0]["src"] if p.get("images") else None
        desc = strip_html(p.get("short_description") or p.get("description") or "")
        price_minor = p.get("prices", {}).get("price")
        price = None
        if price_minor and str(price_minor) != "0":
            price = int(price_minor) / 100

        if price is None:
            try:
                html = fetch_text(permalink)
                price = parse_price_from_html(html)
                # variation data
                var_match = re.search(r'"variations"\s*:\s*(\[[\s\S]*?\])\s*,', html)
                if var_match:
                    try:
                        vars_ = json.loads(var_match.group(1))
                        if vars_:
                            prices = [v.get("display_price") for v in vars_ if v.get("display_price")]
                            if prices:
                                price = min(float(x) for x in prices)
                    except json.JSONDecodeError:
                        pass
            except Exception as e:
                print(f"ERR {slug}: {e}")

        out.append(
            {
                "id": p["id"],
                "slug": slug,
                "name": p["name"],
                "sku": p.get("sku"),
                "categories": cats,
                "image": img,
                "description": desc[:200],
                "price": price,
                "type": p.get("type"),
                "has_options": p.get("has_options"),
            }
        )

    with open("scripts/tostusahane_products.json", "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    cats = {}
    for item in out:
        for c in item["categories"]:
            cats.setdefault(c, 0)
            cats[c] += 1
    print("categories:", cats)
    priced = sum(1 for x in out if x["price"])
    print(f"priced={priced}/{len(out)}")


if __name__ == "__main__":
    main()
