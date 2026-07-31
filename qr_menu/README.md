# Tost-u Şahane — QR Menü

## Müşteri ekranı

1. **Öne çıkanlar** — yönetici seçer (`featured_product_ids`)
2. **Üst kategori navbar** — Tostlar / Sahanda / … (varsayılan: Tostlar)
3. Altında VIP tarzı ürün listesi (görsel · isim · açıklama · fiyat)
4. Masa QR → **Garson Çağır**

## Yönetim

Flutter → **Yönetici → QR Menü**

- Öne çıkanlar: ürün anahtarları
- Menüde göster / gizle
- Masa QR kodları

## Natro

`tostusahane-qr-menu-natro.zip` → `https://www.tostusahane.com/qr/`  
Veri: Cloud Function `getQrMenuPublic`

Masa QR örneği: `https://www.tostusahane.com/qr/?table=1&branch=branch_1`

## Config (gizli)

```bash
cp config.example.js config.js
# config.js içine gerçek Firebase web apiKey / projectId yaz (commit etme)
```
