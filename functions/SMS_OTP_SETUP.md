# SMS OTP (Netgsm) — iOS / Android müşteri kayıt & giriş

Müşteri kayıt/giriş **Netgsm OTP SMS** ile çalışır.

Cloud Functions: `sendSmsOtp` · `verifySmsOtp`  
Flutter: `SmsOtpClient` → kayıt (`RegisterPage`) / giriş (`LoginPage`) → `OtpPage`

## Netgsm panelinde gerekli olanlar

1. **OTP SMS paketi** aktif (satın alındı)
2. Onaylı **gönderici adı** (msgheader), örn. `TOSTUSAHANE`
3. **API alt kullanıcısı** + şifre (SMS / OTP API izni açık)  
   → [API Alt Kullanıcı](https://bilgibankasi.netgsm.com.tr/abonelik-islemleri/diger-islemler/alt-kullanici-olusturma#api-alt-kullancs-nasl-olusturulur)
4. Abone no = usercode (genelde `850xxxxxxx`)

## Ortam değişkenleri

`functions/.env` (deploy’da Functions’a yüklenir):

| Key | Açıklama |
|-----|----------|
| `NETGSM_SMS_USERCODE` | Abone no (örn. `8503028334`) — boşsa `NETGSM_PHONE`’dan türetilir |
| `NETGSM_SMS_PASSWORD` | **API alt kullanıcı şifresi** (zorunlu) |
| `NETGSM_SMS_HEADER` | Onaylı gönderici adı (`TOSTUSAHANE`) |
| `NETGSM_SMS_ENDPOINT` | Opsiyonel; varsayılan `https://api.netgsm.com.tr/sms/send/otp` |

Örnek:

```
NETGSM_SMS_USERCODE=8503028334
NETGSM_SMS_PASSWORD=buraya_api_sifresi
NETGSM_SMS_HEADER=TOSTUSAHANE
```

Deploy:

```bash
firebase deploy --only functions:sendSmsOtp,functions:verifySmsOtp --project tostusahane-e4e71
```

## Akış

1. Kullanıcı ad + telefon girer → `sendSmsOtp`
2. Netgsm OTP API ile 6 haneli kod SMS gider
3. Kullanıcı kodu girer → `verifySmsOtp` → `users/{id}` oluşur/güncellenir
4. Yeni kayıtta adres onboarding’e yönlendirilir

## Notlar

- OTP SMS pazarlama değildir; İYS kampanya izni gerekmez.
- Numara formatı Netgsm’e `5xxxxxxxxx` (10 hane) olarak gider.
- Kod 5 dk geçerli, 60 sn’de bir yeniden gönderim, 5 yanlış denemede kilit.
- Gönderici adı Netgsm’de onaylı olmalı; aksi halde API `41` vb. hata döner.
