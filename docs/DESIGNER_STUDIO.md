# Tasarımcı stüdyosu (Gemini-first)

Kalıp yok. Üretim tamamen Gemini ile yapılır; referans olarak marka logosu + örnek kreatif JPG’ler gönderilir.

## Giriş

Personel girişi:

| Kullanıcı | Şifre | Rol |
|-----------|-------|-----|
| `designer1` | `Sahane123!` | `designer` |

Firestore: `ops_users/d1`

## Akış

1. **Kare (1:1)** veya **Dikey hikaye (9:16)** seç
2. **Karışık üret** (varsayılan) veya kısa kendi isteğini yaz
3. İsteğe bağlı: başlık, katalog ürün, kendi ürün fotoğrafın
4. **Üret** → sonuç ortada görünür
5. **İndir** / **Paylaş** / **Yeniden üret**

## Gemini anahtarı

Sıra:

1. `--dart-define=GEMINI_API_KEY=...` veya `--dart-define-from-file=dart_defines.local.json`
2. Firestore yedek: `meta/designer_settings.gemini_api_key`

Android script `dart_defines.local.json` varsa otomatik ekler:

```powershell
.\scripts\build_android.ps1 -Format apk
```

Yerel çalıştırma:

```bash
flutter run --dart-define-from-file=dart_defines.local.json
```

**Önemli:** Anahtar veya stüdyo kodu değişince hot reload yetmez; uygulamayı yeniden derleyin.

## Marka varlıkları

- Logo: `assets/sosyal/brand/mascot_logo.png`, `wordmark.svg`
- Örnek kreatifler: `assets/sosyal/examples/example_01.jpg` … `06.jpg`
