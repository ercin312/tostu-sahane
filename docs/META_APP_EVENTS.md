# Meta App Events — Tostu Şahane

**Meta App ID:** `1033924819431528`  
**Android package:** `com.tostusahane.tostu_sahane`  
**iOS Bundle ID:** `com.tostusahane.tostuSahane`  
**App Secret:** uygulamada **yok** (yalnızca sunucu / Meta konsol).

## Kurulum (zorunlu)

1. [Meta Developers](https://developers.facebook.com) → uygulama → **Settings → Advanced → Client Token**
2. Değeri yapıştırın:
   - `android/app/src/main/res/values/strings.xml` → `facebook_client_token`
   - `ios/Runner/Info.plist` → `FacebookClientToken`
3. Events Manager’da Android / iOS uygulamalarını aynı Meta App’e bağlayın.

## Ortam ayrımı

| Ortam | Olay gönderilir mi? |
|-------|---------------------|
| `USE_MOCK_API=true` | Hayır |
| Windows OPS desktop | Hayır |
| Debug (varsayılan) | Hayır |
| Release (Play / TestFlight) | Evet |
| `--dart-define=META_TEST_EVENTS=true` | Evet (Test Events için) |

Test Events örneği:

```powershell
flutter run --dart-define=USE_MOCK_API=false --dart-define=META_TEST_EVENTS=true
```

## Olay → ekran haritası

| Meta olayı | Ne zaman | Kod |
|------------|----------|-----|
| `fb_mobile_activate_app` | Uygulama açılışı | `MetaAnalytics.initialize` ← `main.dart` |
| `fb_mobile_complete_registration` | Üyelik başarılı | `register_page.dart` `_submit` |
| `fb_mobile_search` | Menü araması (≥2 karakter, debounce) | `customer_home_page.dart` |
| `fb_mobile_content_view` | Ürün detayı açıldı (ürün başına 1) | `product_detail_page.dart` |
| `fb_mobile_add_to_cart` | Sepete ekle | `product_detail_page.dart` `_addToCart` |
| `fb_mobile_initiated_checkout` | Ödemeye geçiş | `cart_page.dart` checkout butonu |
| `fb_mobile_purchase` | Sipariş başarıyla oluşturuldu | `checkout_page.dart` `_placeOrder` |

### Purchase parametreleri

- `amount` + `currency=TRY`
- `fb_order_id` / `order_number`
- `fb_content` (ürün id + adet + birim fiyat JSON)
- Yerel dedupe: aynı sipariş id bir kez (SharedPreferences)

## Gizlilik / mağaza beyanları

Toplanabilecek veriler (reklam ölçümü):

- Uygulama etkileşimleri (ekran/olaylar)
- Satın alma bilgisi (tutar, sipariş no, ürün id)
- Cihaz reklam kimliği (IDFA / GAID) — **yalnızca ATT / kullanıcı izni varsa**
- Kurulum ilişkilendirme (Play Install Referrer / SKAdNetwork)

iOS: `NSUserTrackingUsageDescription` + ATT diyaloğu. İzin reddedilse de SKAdNetwork / toplu ölçüm açık kalır.  
Android: `AD_ID` izni; Facebook SDK install referrer kullanır.

App Store / Play Data Safety’de “Analytics / Advertising / Purchase history” maddelerini işaretleyin; gizlilik politikasında Meta ölçümünü belirtin.
