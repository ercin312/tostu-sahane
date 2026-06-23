"""tostusahane.com lezzetler menüsünden mock_data ve çeviri dosyalarını üretir."""
from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRODUCTS_JSON = ROOT / "scripts" / "tostusahane_products.json"
MOCK_DATA = ROOT / "lib" / "shared" / "data" / "mock" / "mock_data.dart"
TR_JSON = ROOT / "assets" / "translations" / "tr-TR.json"
EN_JSON = ROOT / "assets" / "translations" / "en-US.json"

KNOWN_PRICES = {
    "kavurmali-kasarli-tost": 210.0,
    "ispanakli-tulumlu-tost": 100.0,
    "sahanda-sucuklu-yumurta": 160.0,
    "sahanda-kavurmali-yumurta": 200.0,
}

DESC_TR = {
    "bazlama-tost": "Bol malzemeli bazlama ekmeğinde şahane tost.",
    "sucuklu-kasarli-tost": "Sucuk ve kaşar ile klasik lezzet.",
    "sucuklu-yumurtali-tost": "Sucuklu yumurtalı bol malzemeli tost.",
    "sucuklu-sebzeli-tost": "Sucuk ve taze sebzelerle hazırlanır.",
    "kasarli-tost": "Bol kaşarlı çıtır tost.",
    "karisik-tost": "Sucuk, kaşar ve domates ile karışık tost.",
    "kavurmali-kasarli-tost": "Kavurmalı, kaşarlı ve yumurtalı bol malzemeli tost.",
    "kavurmali-yumurtali-tost": "Dana kavurma ve yumurta ile özel tost.",
    "pastirmali-kasarli-tost": "Pastırma ve kaşar ile eşsiz lezzet.",
    "pastirmali-yumurtali-tost": "Pastırmalı yumurtalı tost.",
    "beyaz-peynirli-tost": "Beyaz peynirli hafif ve lezzetli tost.",
    "beyaz-peynir-kasarli-tost": "Beyaz peynir ve kaşar bir arada.",
    "ispanakli-kasarli-tost": "Taze ıspanak ve kaşar peyniri.",
    "ispanakli-tulumlu-tost": "Taze ıspanak ve tulum peyniri (vejetaryen).",
    "ispanak-tulum-yumurtali-tost": "Ispanak, tulum peyniri ve yumurta.",
    "ispanakli-yumurtali-tost": "Ispanaklı yumurtalı tost.",
    "yumurta-kasarli-tost": "Yumurta ve kaşarlı tost.",
    "kasarli-sebzeli-tost": "Kaşarlı sebzeli tost.",
    "karisik-sebzeli-tost": "Karışık sebzeli bol malzemeli tost.",
    "akdeniz-tost": "Akdeniz esintili sebzeli özel tost.",
    "protein-bombasi": "Yüksek proteinli özel tost.",
    "menemen": "Taze domates, biber ve yumurta ile menemen.",
    "sahanda-yumurta": "Köy yumurtası ile sahanda yumurta.",
    "sahanda-sucuklu-yumurta": "%100 sucuk ve köy yumurtası.",
    "sahanda-kavurmali-yumurta": "%100 dana kavurma ve köy yumurtası.",
    "patates-kizartmasi": "Çıtır çıtır patates kızartması.",
}

DESC_EN = {
    slug: {
        "bazlama-tost": "Generously filled toast on bazlama bread.",
        "sucuklu-kasarli-tost": "Classic toast with sucuk and cheese.",
        "sucuklu-yumurtali-tost": "Toast with sucuk and egg.",
        "sucuklu-sebzeli-tost": "Toast with sucuk and fresh vegetables.",
        "kasarli-tost": "Crispy cheese toast.",
        "karisik-tost": "Mixed toast with sucuk, cheese and tomato.",
        "kavurmali-kasarli-tost": "Beef stew, cheese and egg toast.",
        "kavurmali-yumurtali-tost": "Special toast with beef stew and egg.",
        "pastirmali-kasarli-tost": "Pastrami and cheese toast.",
        "pastirmali-yumurtali-tost": "Pastrami and egg toast.",
        "beyaz-peynirli-tost": "White cheese toast.",
        "beyaz-peynir-kasarli-tost": "White cheese and cheddar toast.",
        "ispanakli-kasarli-tost": "Fresh spinach and cheese.",
        "ispanakli-tulumlu-tost": "Spinach and tulum cheese (vegetarian).",
        "ispanak-tulum-yumurtali-tost": "Spinach, tulum cheese and egg.",
        "ispanakli-yumurtali-tost": "Spinach and egg toast.",
        "yumurta-kasarli-tost": "Egg and cheese toast.",
        "kasarli-sebzeli-tost": "Cheese and vegetable toast.",
        "karisik-sebzeli-tost": "Mixed vegetable toast.",
        "akdeniz-tost": "Mediterranean style vegetable toast.",
        "protein-bombasi": "High-protein special toast.",
        "menemen": "Menemen with tomato, pepper and egg.",
        "sahanda-yumurta": "Pan-fried village eggs.",
        "sahanda-sucuklu-yumurta": "100% sucuk with village eggs.",
        "sahanda-kavurmali-yumurta": "100% beef stew with village eggs.",
        "patates-kizartmasi": "Crispy french fries.",
    }.get(slug, tr)
    for slug, tr in DESC_TR.items()
}


def slug_key(slug: str) -> str:
    s = unicodedata.normalize("NFKD", slug)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")
    return f"product_{s}"


def normalize_name(name: str) -> str:
    return unicodedata.normalize("NFC", name).replace("\u0327", "")


def estimate_price(slug: str, categories: list[str]) -> float:
    if slug in KNOWN_PRICES:
        return KNOWN_PRICES[slug]
    n = slug
    if "Sahandakiler" in categories:
        if "kavurma" in n:
            return 200.0
        if "sucuk" in n:
            return 160.0
        if "menemen" in n:
            return 140.0
        return 120.0
    if "patates" in n:
        return 75.0
    if "kavurma" in n:
        return 210.0
    if "pastirma" in n:
        return 190.0
    if "protein" in n:
        return 180.0
    if "bazlama" in n:
        return 150.0
    if "karisik" in n:
        return 140.0
    if "sucuk" in n and "yumurta" in n:
        return 150.0
    if "sucuk" in n:
        return 130.0
    if "yumurta" in n:
        return 120.0
    if "ispanak" in n:
        if "tulum" in n:
            return 100.0
        return 110.0
    if "kasar" in n:
        return 95.0
    if "akdeniz" in n or "sebze" in n:
        return 115.0
    if "beyaz-peynir" in n:
        return 90.0
    return 100.0


def map_category(categories: list[str]):
    if "Sahandakiler" in categories:
        return "sahanda"
    if "Atıştırmalıklar" in categories or "Ekstralar" in categories:
        return "snack"
    return "tost"


def color_for_category(cat: str) -> str:
    return {
        "tost": "0xFFFFE0E6",
        "sahanda": "0xFFFFF3E0",
        "snack": "0xFFFFF8E1",
    }[cat]


def main() -> None:
    products = json.loads(PRODUCTS_JSON.read_text(encoding="utf-8"))
    products.sort(key=lambda p: (map_category(p["categories"]), p["name"]))

    tr = json.loads(TR_JSON.read_text(encoding="utf-8"))
    en = json.loads(EN_JSON.read_text(encoding="utf-8"))

    old_prefixes = ("product_mixed_", "product_cheese_", "product_ayvalik_", "product_ayran_", "product_cola_", "product_fries_")
    tr = {k: v for k, v in tr.items() if not k.startswith(old_prefixes)}
    en = {k: v for k, v in en.items() if not k.startswith(old_prefixes)}

    tr["customer_category_sahanda"] = "Sahandakiler"
    en["customer_category_sahanda"] = "Pan Dishes"

    extras_block = """
  static const _tostExtras = [
    ProductExtra(
      id: 'ex_patates',
      name: 'product_patates_kizartmasi_name',
      price: 75,
      imageUrl:
          'https://www.tostusahane.com/wp-content/uploads/2026/01/Patates-Kizartmasi.webp',
    ),
  ];
"""

    dart_products: list[str] = []
    for p in products:
        slug = p["slug"]
        key = slug_key(slug)
        name = normalize_name(p["name"])
        cat = map_category(p["categories"])
        price = estimate_price(slug, p["categories"])
        img = p["image"]
        tr[f"{key}_name"] = name
        tr[f"{key}_desc"] = DESC_TR.get(slug, p["description"][:120])
        en[f"{key}_name"] = name
        en_desc = DESC_EN.get(slug)
        en[f"{key}_desc"] = en_desc if isinstance(en_desc, str) else tr[f"{key}_desc"]

        extras_line = "\n      extras: _tostExtras," if cat == "tost" else ""
        dart_products.append(
            f"""    Product(
      id: 'ts_{slug.replace("-", "_")}',
      nameKey: '{key}_name',
      descriptionKey: '{key}_desc',
      price: {price:.2f},
      category: ProductCategory.{cat},
      imageColorValue: {color_for_category(cat)},
      imageUrl: '{img}',{extras_line}
    ),"""
        )

    mock_content = f"""import '../../../core/localization/locale_keys.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_extra.dart';
import '../../domain/entities/branch.dart';

/// tostusahane.com/lezzetler menüsünden alınan örnek ürünler.
abstract final class MockData {{
  static const demoOtp = '123456';
  static const demoPassword = 'Sahane123!';
  static const deliveryFee = 0.0;
  static const largePortionExtra = 15.0;

  static const branches = [
    Branch(
      id: 'branch_1',
      name: 'Tost-u Şahane Merkez',
      address: 'Cumhuriyet Mh. Muhammed Müftüoğlu Cd.',
      latitude: 40.9872,
      longitude: 29.0284,
      distanceKm: 0.8,
      deliveryRadiusKm: 5.0,
    ),
    Branch(
      id: 'branch_2',
      name: 'Tost-u Şahane Şube',
      address: 'Cumhuriyet Mh. Muhammed Müftüoğlu Cd.',
      latitude: 40.9920,
      longitude: 29.0310,
      distanceKm: 1.2,
      deliveryRadiusKm: 4.0,
    ),
  ];
{extras_block}
  static const products = [
{chr(10).join(dart_products)}
  ];

  static const campaignKeys = [
    LocaleKeys.campaignTitle1,
    LocaleKeys.campaignTitle2,
    LocaleKeys.campaignTitle3,
  ];

  static const categoryKeys = {{
    ProductCategory.all: LocaleKeys.customerCategoriesAll,
    ProductCategory.tost: LocaleKeys.customerCategoryTost,
    ProductCategory.sahanda: LocaleKeys.customerCategorySahanda,
    ProductCategory.drink: LocaleKeys.customerCategoryDrink,
    ProductCategory.snack: LocaleKeys.customerCategorySnack,
  }};

  static const couriers = [
    ('courier_1', 'Ahmet Kurye'),
    ('courier_2', 'Mehmet Kurye'),
  ];

  static const defaultAddress = 'Cumhuriyet Mh. Muhammed Müftüoğlu Cd.';
}}
"""
    MOCK_DATA.write_text(mock_content, encoding="utf-8")
    TR_JSON.write_text(json.dumps(tr, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    EN_JSON.write_text(json.dumps(en, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(products)} products")


if __name__ == "__main__":
    main()
