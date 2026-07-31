# Telefon AI sipariş (ElevenLabs Agents)

Sesli asistan aramayı alır → sipariş + adres toplar → Firestore’a yazar → Windows ops uyarır / mutfak fişi **TELEFON SİPARİŞİ** basar.

## “Aradığınız kişi şu an cevap veremiyor” checklist

Bu mesaj = Netgsm hattı açık ama **çağrı ElevenLabs’e düşmüyor** (veya agent bağlı değil). Sipariş oluşmaz; önce ses bağlantısı şart.

1. Netgsm SIP Trunk: IP = `sip.rtc.elevenlabs.io`, protokol = **TCP**, Kaydet (+ SMS kodu)
2. Prefix: Arayan `0`, Aranan `+90`
3. ElevenLabs → Phone Numbers → `+908503028334` import edilmiş mi?
4. O numaraya **Agent** atanmış mı? (First message: *Buyrun, Tost-u Şahane.*)
5. Voice ID: `N0wraTTB0pquzsz3DLG8`
6. Agent Tools: `lookupPhoneCustomer` + `createPhoneOrder` webhook’ları bağlı mı?

ElevenLabs tarafı bitmeden arama AI’ya gitmez / cevap vermez.

## ElevenLabs ayarları

| Ayar | Değer |
|------|--------|
| **Voice ID** | `N0wraTTB0pquzsz3DLG8` |
| Model | `eleven_multilingual_v2` |
| API Key | Firebase / `functions/.env` |

```bash
firebase deploy --only functions:createPhoneOrder,functions:lookupPhoneCustomer,functions:importPhoneCustomers,functions:listPhoneCustomers
```

## Müşteri defteri (adres hafızası)

Koleksiyon: `phone_customers/{10hane}`

- Her telefon siparişinde isim / firma / adres otomatik kaydolur
- `lookupPhoneCustomer` → `confirmAddress: true` + `agentHint`  
  Örnek: *“Yılmaz Ltd için kayıtlı adres: Oba Mah… Aynı adrese mi gitsin?”*
- Müşteri “evet / aynı” derse `createPhoneOrder` adres göndermeden veya `useSavedAddress: true` ile kayıtlı adresi kullanır

### Agent’ı otomatik yapılandır (önerilen)

Agent şu an boş prompt + tools ile kalırsa ürün anlatır, adres sormaz, sipariş yazmaz.

1. ElevenLabs → API Keys → **ElevenAgents: Write** yetkili key oluştur  
2. PowerShell:

```powershell
cd "C:\Users\excalibur\Desktop\Tostu Sahane"
$env:ELEVENLABS_API_KEY="sk_WRITE_KEY"
node scripts/configure_elevenlabs_phone_agent.js
```

Script şunları yazar:
- Kısa TR prompt + garson POS menü (`productId` listesi)
- Webhook: `lookup_phone_customer` → `lookupPhoneCustomer`
- Webhook: `create_phone_order` → `createPhoneOrder`
- First message: *Buyrun, Tost-u Şahane.*
- Voice: `N0wraTTB0pquzsz3DLG8`

3. ElevenLabs Agents panelinde **Publish**

Prompt kaynağı: `functions/agent_prompt_tostu.md`  
Menü dump: `functions/phone_menu_catalog.json` (`node scripts/export_phone_menu_catalog.js`)

### Agent prompt (özet)

```
Açılış: Buyrun, Tost-u Şahane.
Önce lookup_phone_customer(caller) çağır.
Adres varsa: "Aynı adrese mi?" — evetse useSavedAddress=true.
Çeşit söyleyince anlatma; eksikse "sade mi salçalı mı?" diye sor.
Onay sonrası create_phone_order; sipariş no söyle; end_call.
```

## Excel / eski numaralar

### Uygulama (yönetici)

**Yönetici → Telefon müşterileri** → Excel’den CSV yapıştır → İçe aktar  
Sütunlar: `telefon;isim;firma;adres;tarif`  
Şablon: `scripts/phone_customers_template.csv`

Excel: Dosya → Farklı Kaydet → **CSV (Virgülle veya noktalı virgülle ayrılmış)**

### Komut satırı (.xlsx)

```bash
cd functions && npm i xlsx
node ../scripts/import_phone_customers.js "C:\path\musteriler.xlsx"
```

## Cloud Functions

| Function | İş |
|----------|-----|
| `lookupPhoneCustomer` | Numara → isim/firma/adres |
| `createPhoneOrder` | Sipariş + deftere yaz |
| `importPhoneCustomers` | Toplu Excel/CSV |
| `listPhoneCustomers` | Admin listesi |

## SIP / hat

| Ayar | Değer |
|------|--------|
| Numara | `0850 302 83 34` → `+908503028334` |
| SIP kullanıcı | `8503028334` |
| SIP sunucu | `sip.netgsm.com.tr` |
| Gelen | `sip.rtc.elevenlabs.io` · **TCP** |

## Güvenlik

API key / SIP şifresi / `PHONE_ORDER_SECRET` sohbete yazma.
