import urllib.request
import re

url = "https://www.tostusahane.com/product-category/tostlar/"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
html = urllib.request.urlopen(req, timeout=60).read().decode("utf-8", errors="ignore")
open("scripts/tostlar_page.html", "w", encoding="utf-8").write(html)

# product links
links = re.findall(r'/product/([a-z0-9-]+)/', html)
print("links", len(set(links)))

# price spans near product titles
blocks = re.findall(r'<h2 class="woocommerce-loop-product__title".*?</li>', html, re.S)
print("blocks", len(blocks))
for b in blocks[:5]:
    title = re.search(r'>([^<]+)<', b)
    price = re.search(r'woocommerce-Price-amount[^>]*>.*?([0-9.,]+)', b, re.S)
    print(title.group(1).strip() if title else '?', price.group(1) if price else 'no price')
