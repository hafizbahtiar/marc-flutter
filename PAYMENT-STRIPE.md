# Stripe Donation — Setup & Reference

Status: **jalan hujung-ke-hujung dengan pembayaran sebenar** (kad;
FPX belum diuji — lihat "Yang belum"). Ni bahagian **Stripe sahaja**
drpd payment module — yuran ahli (ToyyibPay) dan donation <RM500
(SociaBuzz) belum start.

## Kenapa dua akaun berasingan

- **ToyyibPay** — untuk yuran ahli (belum start). Bukan skop dokumen ni.
- **Stripe** — akaun **peribadi** (pemaju app), untuk "Sokong MARC".
  Amount ≥RM500 guna Stripe; <RM500 akan guna SociaBuzz (belum wired).
  Currency **MYR sahaja** — elak isu penukaran mata wang.

### Framing: sokongan kepada pemaju, BUKAN sumbangan kepada MAIWP

Duit dari `/donate` masuk ke akaun peribadi pemaju untuk menampung kos
hosting, domain dan penyelenggaraan. Ia **bukan** derma kepada MAIWP atau
mana-mana badan amal, dan **tidak layak pelepasan cukai**.

Ini kena kekal jelas di **empat** tempat sekaligus — jangan ubah satu tanpa
yang lain, sebab resit yang nampak macam dokumen rasmi MAIWP untuk duit
yang masuk akaun individu adalah salah nyata:

1. `marc_flutter/lib/features/donation/donation_page.dart` — `_DeveloperStory`
2. `marc_go/internal/http/handlers/donations.go` — `donationReceiptHTML`
   (perenggan footer)
3. `marc_go/internal/receipt/receipt.go` — pemalar `footerNote` + baris
   "Penerima"/"Tujuan" dalam jadual
4. `marc_flutter/lib/features/profile/about_page.dart` + `faq_page.dart` —
   penafian "bukan aplikasi rasmi MAIWP". Dilindungi `about_page_test.dart`
   supaya dakwaan lama tak kembali senyap.

Sebab tu juga tajuk PDF ialah "RESIT SOKONGAN", bukan "Resit Rasmi", dan
header tak lagi bawa nama penuh MAIWP.

## Cara bayar: `PaymentSheet` (bukan `CardFormField`)

Keputusan 2026-08-09: guna Stripe **`PaymentSheet`**, bukan
`CardFormField` manual. Sebab: donor Malaysia jauh lebih biasa guna
**FPX** (online banking terus dari akaun bank) drpd kad — `CardFormField`
cuma boleh kad, `PaymentSheet` auto-papar SEMUA payment method yang
aktif di dashboard Stripe (kad + FPX sekali), termasuk uruskan
round-trip redirect FPX (keluar app ke bank, authenticate, balik) sendiri.

Kesan pada `donation_page.dart`: borang amount → terus panggil
`handler.handle()`, TIADA lagi skrin "isi maklumat kad" berasingan —
`PaymentSheet` ialah UI pembayaran sepenuhnya, dikawal Stripe sendiri.

## Setup redirect FPX (urlScheme) — WAJIB untuk FPX

FPX perlukan URL scheme khusus supaya app boleh "resume" lepas user
authenticate kat laman bank:

- `lib/app/stripe.dart`: `Stripe.urlScheme = 'marc'` (dipanggil sebelum
  `applySettings()`); `stripeReturnUrl = 'marc://stripe-redirect'`
  dihantar sebagai `returnURL` masa `initPaymentSheet()`
  (`donation_gateway.dart`).
- **Android** (`AndroidManifest.xml`): intent-filter `VIEW` +
  `BROWSABLE` dengan `android:scheme="marc"
  android:host="stripe-redirect"` pada `.MainActivity`, + meta-data
  `com.google.android.gms.wallet.api.enabled` (diperlukan internal
  Stripe PaymentSheet).
- **iOS** (`Info.plist`): `CFBundleURLTypes` dengan
  `CFBundleURLSchemes: [marc]`.

### FPX TIDAK tersedia untuk akaun ni (disahkan 2026-08-09)

FPX **bukan tetapan yang terlepas** — ia tak ditawarkan langsung pada akaun
ini, sebab tu ia tiada dalam senarai Payment methods di Dashboard.

Bukti muktamad ialah medan `available` dalam konfigurasi kaedah pembayaran,
BUKAN `display_preference`:

```bash
KEY=$(grep '^STRIPE_SECRET_KEY=' .env | cut -d= -f2-)
curl -s -u "$KEY:" https://api.stripe.com/v1/payment_method_configurations \
  | python3 -c "
import json,sys
for c in json.load(sys.stdin)['data']:
    for k in ['fpx','card','grabpay']:
        v=c.get(k)
        if v: print(k, v)
"
```

Keadaan semasa:

```
fpx     -> available: false, preference: off
grabpay -> available: true,  preference: on
card    -> available: true,  preference: on
```

**Jangan tertipu dengan `preference: off` sahaja.** Itu yang menyesatkan
pada mulanya — nampak macam toggle yang belum dihidupkan, sedangkan
`available: false` bermakna tiada toggle pun wujud.

**Sebab**: dokumentasi FPX Stripe menyatakan Stripe memerlukan **Business
Registration Number (BRN)** untuk memproses caj FPX *dan* menerima payout,
atas sebab pematuhan kawal selia. Akaun ni:

```
business_type           : individual
company.tax_id_provided : None
capabilities            : card_payments, grabpay_payments, link_payments,
                          transfers  (semua inactive) — tiada fpx_payments
charges_enabled         : False
```

Tiada BRN → tiada keupayaan `fpx_payments` → `available: false`.

**Untuk mengaktifkannya**: daftar SSM (pemilikan tunggal/Enterprise sudah
memadai, tak perlu Sdn Bhd), hantar BRN kepada Stripe, dan lengkapkan
pengaktifan akaun. Ini langkah pentadbiran dunia sebenar — bukan tetapan
Dashboard atau perubahan kod.

Nota: mencipta PaymentIntent dengan `payment_method_types[]=fpx` secara
eksplisit MASIH berjaya walaupun `available: false` — pengesahan
(confirmation) yang akan gagal, bukan penciptaan. Jangan guna kejayaan
`create` sebagai bukti FPX berfungsi.

Nota kedua: akaun ni sebenarnya **Sandbox** (`company.name` =
"hafizbahtiar sandbox"), dan semua keupayaan `inactive` — jadi mod live pun
belum boleh menerima kad.

### Laluan untuk mengaktifkan FPX: SSM → BRN → aktifkan semula Stripe

Urutan ni bukan kerja kod. Setiap langkah menyekat yang seterusnya.

**1. Daftar SSM.** Pemilikan tunggal (Perniagaan/Enterprise) sudah memadai
— tak perlu Sdn Bhd. Daftar melalui SSM BizChannel atau kaunter SSM.
Hasilnya nombor pendaftaran perniagaan (**BRN**).

**2. Kemas kini akaun Stripe.** Akaun semasa ialah **Sandbox**
(`company.name` = "hafizbahtiar sandbox") dengan `business_type:
individual`. Untuk FPX kau perlukan akaun SEBENAR dengan butiran
perniagaan:

- Tukar/lengkapkan `business_type` kepada perniagaan berdaftar
- Hantar **BRN**
- Hantar **MY TIN** (nombor pengenalan cukai)
- Hantar **SST** kalau berdaftar SST
- Lengkapkan pengesahan identiti + akaun bank untuk payout

Nota: untuk pengesahan akaun UMUM, Stripe menerima MyKad/passport sebagai
ganti BRN. Tetapi **FPX secara khusus memerlukan BRN** — dokumentasi FPX
menyatakan ia diperlukan untuk memproses caj DAN menerima payout. Jadi
MyKad sahaja tak cukup untuk membuka FPX.

**3. Tunggu pengaktifan.** Semak dengan API, bukan dengan mata:

```bash
KEY=$(grep '^STRIPE_SECRET_KEY=' .env | cut -d= -f2-)
curl -s -u "$KEY:" https://api.stripe.com/v1/account | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('charges_enabled:', d['charges_enabled'])
print('capabilities   :', d['capabilities'])
"
```

Tunggu sehingga `charges_enabled: true` dan `fpx_payments` muncul dalam
capabilities.

**4. Hidupkan FPX**, kemudian sahkan `available: true` (bukan sekadar
`preference: on`) guna arahan dalam bahagian di atas.

**5. Kunci baharu.** Akaun sebenar ada kunci API sendiri — kemas kini
`STRIPE_SECRET_KEY` + `STRIPE_PUBLISHABLE_KEY` dalam `.env` dan Railway,
dan daftar semula webhook (rahsia penandatanganan baharu).

**6. Uji pusingan redirect FPX sebenar** — belum pernah dibuat; setakat ni
kad sahaja disahkan hujung-ke-hujung.

#### Kesan sampingan yang mudah terlepas pandang

- **Framing sumbangan berubah.** Sekarang resit + halaman sokongan kata
  duit pergi "secara peribadi kepada pembangun". Selepas berdaftar SSM,
  ia masuk ke akaun PERNIAGAAN — teks tu kena disemak semula (empat tempat
  yang disenaraikan di atas), dan layanan cukai mungkin berbeza.
- **e-Invois LHDN.** Perniagaan berdaftar Malaysia tertakluk kepada mandat
  e-Invois mengikut ambang hasil dan tarikh berperingkat. Semak sama ada
  ia terpakai sebelum menerima bayaran sebenar.
- **DuitNow QR peribadi kekal berfungsi** dan tiada yuran — pendaftaran
  SSM tak memaksa kau membuangnya.

## DuitNow — Stripe TAK menyokongnya

Disahkan terhadap jadual sokongan kaedah pembayaran Stripe: Malaysia dapat
**FPX, GrabPay dan kad sahaja**. "DuitNow" tak wujud langsung dalam dokumen
itu — bukan tetapan yang terlepas.

Gateway tempatan yang menyokong DuitNow QR (Billplz, ToyyibPay) perlukan
akaun merchant; Billplz perlukan syarikat berdaftar. Jadi app ni papar
**QR DuitNow peribadi** sebagai laluan tanpa yuran
(`lib/features/donation/widgets/duitnow_qr_card.dart`), dengan amaran jelas
bahawa bayaran QR memintas backend — tiada baris `donations`, tiada resit.

## Native Android — `MainActivity` mesti `FlutterFragmentActivity`

Satu je perubahan native WAJIB yang tinggal (dulu ada beberapa lagi khas
untuk `CardFormField`'s `MaterialCardView`/dropdown negara — semua tu
dah tak relevan lepas swap ke `PaymentSheet`, appearance `PaymentSheet`
dikawal terus dari Dart via `PaymentSheetAppearance`, bukan native theme
XML):

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
class MainActivity : FlutterFragmentActivity()
```

Native Stripe SDK guna Fragment untuk UI kad/3DS/PaymentSheet — app
crash masa init kalau `MainActivity` kekal `FlutterActivity` biasa.

iOS: tiada perubahan native tambahan (`IPHONEOS_DEPLOYMENT_TARGET` dah
13.0, cukup untuk `flutter_stripe`).

Nota sejarah (kekal dlm auto-memory `marc-flutter-stripe-android-quirks`
untuk rujukan): fasa `CardFormField` dulu perlukan `Theme.MaterialComponents`
+ `forceDarkAllowed=false` + `colorSurface`/`colorOnSurface` eksplisit
untuk elak popup dropdown negara render gelap, dan poskod native
auto-hide ikut negara (US/Canada sahaja). Isu-isu ni khusus
`CardFormField`, tak applicable lagi dengan `PaymentSheet`.

## Dark mode — `PaymentSheetAppearance` ikut tema semasa

App ni sekarang support dark mode penuh (`AppTheme.light`/`AppTheme.dark`
di `lib/app/theme.dart`, toggle di Profile page → "Mod Gelap",
`themeModeProvider` persisted via `shared_preferences`).
`PaymentSheetAppearance` cuma terima SATU set warna (tiada slot dark
berasingan dlm API) — `StripeCheckoutHandler.handle()` terima
`BuildContext` supaya boleh baca `Theme.of(context).colorScheme` SEBELUM
`await` pertama dan bina `PaymentSheetAppearance` yang padan mod semasa
(bukan hardcode light).

## Seni bina — Strategy pattern (`payment.Gateway`)

Backend (`marc_go`) definekan satu interface sepunya untuk SEMUA payment
provider (Stripe sekarang, ToyyibPay/SociaBuzz akan datang):

```go
// internal/payment/payment.go
type Gateway interface {
    Name() string
    Enabled() bool
    CreatePayment(ctx, CreateParams) (CreateResult, error)
    VerifyWebhook(payload []byte, headers http.Header) (WebhookEvent, error)
}
```

`CreateResult{GatewayRef, ClientSecret, RedirectURL}` sengaja union type
— HANYA SATU antara `ClientSecret`/`RedirectURL` diisi ikut model
gateway:
- **Stripe** = client-side confirm (`PaymentSheet`) → `ClientSecret` diisi
- **ToyyibPay/SociaBuzz** (akan datang) = hosted-redirect page →
  `RedirectURL` diisi

Flutter cerminkan pattern yang sama supaya UI tak pernah hardcode
andaian "mesti Stripe":

```dart
// lib/features/donation/donation_gateway.dart
abstract class DonationCheckoutHandler {
  Future<DonationResult> handle(BuildContext context, DonationCheckoutResponse response);
}
```

`donation_page.dart` panggil `/donations/checkout`, dapat balik
`{gateway, client_secret, redirect_url}`, lookup handler ikut
`response.gateway` dlm `donationCheckoutHandlersProvider`, delegate.
Tambah gateway baru = implement `Gateway` (Go) + `DonationCheckoutHandler`
(Dart) + daftar satu baris dalam registry masing-masing — TIADA
perubahan pada handler/routing/page sedia ada.

## Traceability (kenapa emel kadang wajib, kadang tidak)

Keputusan produk: **semua donation kena ada jejak dalaman**, walau
anonymous.

- Ahli MARC yang log masuk → `middleware.OptionalAuth` kaitkan `user_id`
  automatik (trace balik ke emel akaun terus), jadi emel **tak wajib**.
  Field tu tetap DIPAPAR dan di-prefill drpd profil — bukan disorok.
  Menyorokkannya (reka bentuk asal) buat borang nampak kosong/pelik, dan
  lebih teruk: `isLoggedIn` dulu diambil drpd `myProfileProvider` yang
  async, jadi field muncul sekejap kemudian hilang semasa profil selesai
  dimuat — nampak macam "emel dikosongkan". Sekarang ia baca
  `authNotifierProvider` yang segerak.
- Guest (tak log masuk) → **wajib isi emel**, endpoint tolak 400 kalau
  kosong. Dikuatkuasakan DUA lapis: validator borang Flutter + DB
  constraint `donations_traceable` (`user_id is not null or donor_email
  is not null`) di backend.

## Resit emel

Lepas webhook Stripe sahkan `payment_intent.succeeded`,
`DonationHandler.sendReceiptEmail` (`marc_go/internal/http/handlers/donations.go`)
hantar resit ke `donor_email` (guest) atau emel akaun (`GetUserByID`,
kalau donor log masuk & tak isi emel). Best-effort — kegagalan hantar
emel TAK gagalkan webhook. Dihantar TEPAT SEKALI per donation (bukan
setiap retry Stripe) sebab bergantung pada `UpdateDonationStatusByGatewayRef`
yang idempotent (row cuma "benar-benar beralih" ke `succeeded` sekali).

### PDF resit (`marc_go/internal/receipt`)

Resit satu muka surat, dilampirkan sebagai
`Resit-MARC-<gateway_ref>.pdf`. Susun atur: jalur header berjenama
(wordmark + no. rujukan) → blok penderma + tarikh + lencana status →
panel jumlah (angka besar + **jumlah dieja dalam BM**, cth "Ringgit
Malaysia Seribu Lima Ratus sahaja") → jadual butiran transaksi berselang
warna → footer nota.

Perkara yang senang terlepas kalau edit fail ni:

- **Tarikh sentiasa MYT.** `malaysiaTZ` ialah `time.FixedZone` (bukan
  `LoadLocation`) — imej container tak semestinya ada tzdata. Stripe
  hantar masa dalam UTC; tanpa penukaran ni resit tunjuk jam salah.
- **Font teras fpdf guna cp1252, bukan UTF-8.** Semua string dinamik
  MESTI melalui `tr := pdf.UnicodeTranslatorFromDescriptor("")`, kalau
  tidak nama berdiakritik jadi sampah.
- **fpdf tak clip teks.** Nilai panjang (emel, nama) kena lalu `clip()`
  atau ia melimpah menindih lajur sebelah.
- Ejaan jumlah dilangkau untuk mata wang bukan MYR (ejaan BM tak sesuai
  untuk USD/SGD).

Ujian: `go test ./internal/receipt/` — cover jumlah dieja, pemisah
ribuan, dan render sumbangan awanama (semua field kosong) tanpa panik.

## File map

**Backend (`marc_go`)**
```
internal/payment/payment.go              -- interface Gateway + types
internal/payment/stripe.go                -- StripeGateway implements Gateway
internal/http/handlers/donations.go       -- POST /donations/checkout, POST /webhooks/:gateway
internal/http/middleware/auth.go          -- OptionalAuth + UserIDOptional
internal/db/migrations/20260809100000_create_donations.sql
queries/donations.sql
cmd/api/main.go                           -- registry: map[string]payment.Gateway{"stripe": ...}
```

**Frontend (`marc_flutter`)**
```
lib/features/donation/donation_models.dart     -- DonationCheckoutResponse, DonationResult
lib/features/donation/donation_gateway.dart    -- DonationCheckoutHandler + StripeCheckoutHandler (PaymentSheet) / RedirectCheckoutHandler
lib/features/donation/donation_providers.dart  -- handler registry, DonationRepository
lib/features/donation/donation_page.dart       -- form -> checkout -> handler.handle(); prefill nama/emel drpd profil bila log masuk
lib/app/stripe.dart                             -- init Stripe.publishableKey + urlScheme (no-op kalau kosong)
lib/app/theme.dart                              -- AppTheme.light/dark + AppSemanticColors
lib/core/theme_mode_provider.dart               -- ThemeMode toggle, persisted
```

**Backend — resit (tambahan)**
```
internal/receipt/receipt.go   -- jana PDF resit (go-pdf/fpdf)
internal/email/client.go      -- SendWithAttachments (base64, Resend)
```

Entry point: Profile page → "Sokong MARC" → `/donate`.

## Setup — env vars

**`marc_go/.env`** (gitignored — JANGAN letak kat `.env.example`, lihat
"Insiden" di bawah):
```
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=            # Stripe Dashboard -> Developers -> Webhooks -> signing secret
```

**`marc_flutter/.env`** (gitignored — publishable key je, BUKAN secret,
selamat di client walaupun bocor):
```
STRIPE_PUBLISHABLE_KEY=pk_test_...
```

Kedua-dua kosong = fail graceful (503 backend / donation page disabled
client — no-op, bukan crash), padanan pattern R2/OneSignal sedia ada.

## Test cards (Stripe test mode)

Dalam `PaymentSheet`, pilih "Card" sebagai payment method, isi:

```
Nombor kad : 4242 4242 4242 4242
Tarikh luput : 12/34   (mana-mana tarikh depan)
CVC        : 123        (mana-mana 3 digit)
```

Nombor kad lain untuk test scenario berbeza:

| Nombor kad | Hasil |
|---|---|
| `4242 4242 4242 4242` | Berjaya, tiada 3DS |
| `4000 0025 0000 3155` | Perlukan 3DS (test "requires action" flow) |
| `4000 0027 6000 3184` | 3DS, berjaya kalau authenticate |
| `4000 0000 0000 9995` | Ditolak — insufficient funds |
| `4000 0000 0000 0002` | Ditolak — generic |

FPX test mode: Stripe sediakan bank simulasi test-mode automatik bila
pilih FPX dalam `PaymentSheet` (test mode) — tak perlu akaun bank
sebenar.

Semua ni **cuma jalan dalam Stripe test mode** (`sk_test_`/`pk_test_`
key) — tak boleh dipakai production/live key.

## Insiden git (2026-08-09) — pengajaran

`STRIPE_SECRET_KEY`/`STRIPE_PUBLISHABLE_KEY` sekali pernah termasuk
tersilap ke dalam `.env.example` (fail yang **di-track git**) di
`marc_go`, bukan `.env` (gitignored). Sudah dibetulkan — commit yang
terlibat (`c170391`) di-amend sebelum sempat push ke `origin` (belum
ada di GitHub langsung), jadi secret **tidak pernah bocor** ke remote.

**Peraturan**: `.env.example` — placeholder/kosong SAHAJA, tak kira
environment. Real credential (test ATAU live) letak `.env` je.

## Webhook API-version gotcha (2026-08-09) — WAJIB baca kalau webhook 400 lagi

`stripe-go` v82.5.1 pin API version `2025-08-27.basil`. Kalau akaun
Stripe kau emit event dgn API version release-train lain (cth
`2025-10-29.clover` — semak `curl https://api.stripe.com/v1/events -u
$STRIPE_SECRET_KEY:`), `webhook.ConstructEvent` akan **reject event yg
signature-nya SAH** dgn error generic — nampak SAMA PERSIS macam
signing secret salah (400 "signature tidak sah"), tapi puncanya version
mismatch, bukan secret. `internal/payment/stripe.go` dah fix guna
`ConstructEventWithOptions{IgnoreAPIVersionMismatch: true}`. Kalau
jumpa 400 webhook lagi lepas ni — **jangan terus syak secret/delete-
recreate endpoint**, semak log server dulu (`donations.go` webhook
400-path skrg log ralat SEBENAR drpd `VerifyWebhook`, bukan senyap).

## Yang belum

- [ ] **FPX tak tersedia** (`available: false`) — perlukan BRN/SSM. Lihat
      "FPX TIDAK tersedia" di atas. Bukan kerja kod; sehingga akaun
      didaftarkan, laluan Malaysia ialah DuitNow QR + kad (+ GrabPay yang
      dah aktif).
- [ ] **Akaun Stripe belum diaktifkan untuk mod live**: `details_submitted:
      true` tapi `charges_enabled: false` dan `card_payments: inactive`,
      tanpa `currently_due` atau `disabled_reason` — Stripe masih memproses,
      bukan sesuatu yang tertunggak di pihak kau. Mod test tak terjejas.
- [ ] **Threshold RM500 belum wired.** `DonationHandler.selectGateway`
      sentiasa pulang Stripe tak kira amount.
- [ ] **SociaBuzz** — belum research langsung: ada API/webhook rasmi untuk
      verify pembayaran, atau manual sahaja?
- [ ] **ToyyibPay** (yuran ahli + gate feed) — belum start.
- [ ] **Ujian automatik untuk `donation_page.dart`** — setakat ni bergantung
      pada `flutter analyze` + ujian sebenar pada peranti.

## Status disahkan

- Donation sebenar hujung-ke-hujung (2026-08-09): checkout → Stripe confirm
  → webhook 200 → DB `succeeded` → resit PDF + emel dihantar.
- Webhook didaftar (`we_1U2FwsFV4EgsAdJtmpB7SrcG`), `STRIPE_WEBHOOK_SECRET`
  diset di Railway staging + `.env` tempatan.
