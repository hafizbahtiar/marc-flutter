# Stripe Donation — Setup & Reference

Status: **backend + Flutter UI done, belum diverify end-to-end lawan Stripe
sebenar** (test keys dah ada dlm `.env` kedua-dua repo). Ni bahagian
**Stripe sahaja** drpd payment module (Stage 12) — yuran ahli (ToyyibPay)
dan donation <RM500 (SociaBuzz) **belum start**, lihat "Yang belum" di
bawah dan `marc_go/TODO.md` Stage 12 untuk gambaran penuh.

## Kenapa dua akaun berasingan

- **ToyyibPay** — akaun rasmi MAIWP (non-profit), untuk yuran ahli. Bukan
  skop dokumen ni.
- **Stripe** — akaun **peribadi** (pemaju app), khas untuk "Donate to
  us". Amount ≥RM500 guna Stripe; <RM500 akan guna SociaBuzz (belum
  wired). Currency **MYR sahaja** — elak isu penukaran mata wang.

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
- **Stripe** = client-side confirm → `ClientSecret` diisi
- **ToyyibPay/SociaBuzz** (akan datang) = hosted-redirect page →
  `RedirectURL` diisi

Flutter cerminkan pattern yang sama supaya UI tak pernah hardcode
andaian "mesti Stripe":

```dart
// lib/features/donation/donation_gateway.dart
abstract class DonationCheckoutHandler {
  Future<DonationResult> handle(DonationCheckoutResponse response);
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
  automatik (trace balik ke emel akaun terus). **Emel TAK ditanya** dlm
  UI — `donation_page.dart` sorok field emel terus bila `isLoggedIn`.
- Guest (tak log masuk) → **wajib isi emel**, endpoint tolak 400 kalau
  kosong. Dikuatkuasakan DUA lapis: validator borang Flutter + DB
  constraint `donations_traceable` (`user_id is not null or donor_email
  is not null`) di backend.

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
lib/features/donation/donation_gateway.dart    -- DonationCheckoutHandler + StripeCheckoutHandler/RedirectCheckoutHandler
lib/features/donation/donation_providers.dart  -- handler registry, DonationRepository
lib/features/donation/donation_page.dart       -- form -> checkout -> CardFormField -> confirm
lib/app/stripe.dart                             -- init Stripe.publishableKey (no-op kalau kosong)
```

Entry point: Profile page → "Donate" → `/donate`.

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

## Setup native Android — WAJIB, bukan optional

`flutter_stripe` perlukan TIGA perubahan native Android, kalau tak app
crash (atau UI clash tema) bila buka `donation_page.dart` / `CardFormField`:

1. **`MainActivity` mesti `FlutterFragmentActivity`**, bukan
   `FlutterActivity` biasa (native Stripe SDK guna Fragment untuk
   kad/3DS):
   ```kotlin
   // android/app/src/main/kotlin/.../MainActivity.kt
   class MainActivity : FlutterFragmentActivity()
   ```
2. **`NormalTheme` mesti descendant `Theme.MaterialComponents`**, bukan
   platform `Theme.Light.NoTitleBar` — `CardFormField` guna
   `MaterialCardView` yang requires tema Material:
   ```xml
   <!-- android/app/src/main/res/values{,-night,-v31,-night-v31}/styles.xml -->
   <style name="NormalTheme" parent="@style/Theme.MaterialComponents.Light.NoActionBar">
   ```
   **Kesemua 4 variant** (`values`, `values-v31`, `values-night`,
   `values-night-v31`) guna `.Light.NoActionBar` yang SAMA — termasuk
   folder `-night`. Sengaja BUKAN `.Light` untuk night dielakkan: app
   Flutter ni tiada `darkTheme` (`main.dart` cuma `theme: AppTheme.light`),
   jadi UI Flutter kekal light tak kira system dark mode. Kalau
   `NormalTheme` folder `-night` guna dark variant, native platform view
   (`CardFormField` + dropdown negara/poskod dalamnya) jadi gelap
   sedangkan UI Flutter sekeliling tetap light — nampak macam bug
   (dropdown background gelap terpisah dari page).
3. **`android:forceDarkAllowed="false"` pada `NormalTheme`** (kesemua 4
   variant) — langkah 2 sahaja **TAK CUKUP**. Android "Force Dark"
   (API 29+) re-warna native View (bukan kanvas Flutter) secara automatik
   bila system dark mode ON, **tak kira apa parent tema View tu** —
   kena disable eksplisit setiap tema, bukan cuma pilih parent Light:
   ```xml
   <style name="NormalTheme" parent="@style/Theme.MaterialComponents.Light.NoActionBar">
       <item name="android:windowBackground">?android:colorBackground</item>
       <item name="android:forceDarkAllowed">false</item>
   </style>
   ```

Ketiga-tiga dah applied dlm codebase — catatan ni untuk rujukan kalau
`MainActivity`/`styles.xml` di-regenerate (`flutter create .` dsb boleh
overwrite balik ke default).

**Default negara**: `CardFormField(countryCode: 'MY', ...)` di
`donation_page.dart` — set Malaysia sebagai default drpd biar user
pilih sendiri dari dropdown (kebanyakan donor MAIWP di Malaysia).

iOS: tiada perubahan native diperlukan setakat ni (`IPHONEOS_DEPLOYMENT_
TARGET` dah 13.0, cukup untuk `flutter_stripe`).

## Test cards (Stripe test mode)

Quick test (happy path) — isi terus dalam `CardFormField`:

```
Nombor kad : 4242 4242 4242 4242
Tarikh luput : 12/34   (mana-mana tarikh depan)
CVC        : 123        (mana-mana 3 digit)
Poskod     : 12345      (mana-mana, enablePostalCode default true)
```

Nombor kad lain untuk test scenario berbeza — expiry/CVC/poskod sama
macam atas (mana-mana nilai sah), cuma nombor kad je tukar:

| Nombor kad | Hasil |
|---|---|
| `4242 4242 4242 4242` | Berjaya, tiada 3DS |
| `4000 0025 0000 3155` | Perlukan 3DS (test "requires action" flow) |
| `4000 0027 6000 3184` | 3DS, berjaya kalau authenticate |
| `4000 0000 0000 9995` | Ditolak — insufficient funds |
| `4000 0000 0000 0002` | Ditolak — generic |

Semua kad ni **cuma jalan dalam Stripe test mode** (`sk_test_`/`pk_test_`
key) — tak boleh dipakai production/live key.

## Insiden git (2026-08-09) — pengajaran

`STRIPE_SECRET_KEY`/`STRIPE_PUBLISHABLE_KEY` sekali pernah termasuk
tersilap ke dalam `.env.example` (fail yang **di-track git**) di
`marc_go`, bukan `.env` (gitignored). Sudah dibetulkan — commit yang
terlibat (`c170391`) di-amend sebelum sempat push ke `origin` (belum
ada di GitHub langsung), jadi secret **tidak pernah bocor** ke remote.

**Peraturan**: `.env.example` — placeholder/kosong SAHAJA, tak kira
environment. Real credential (test ATAU live) letak `.env` je.

## Yang belum (lihat `marc_go/TODO.md` Stage 12 untuk detail penuh)

- [ ] **Verify end-to-end lawan Stripe sebenar** — test keys dah masuk
  `.env`, belum run full flow (checkout -> CardFormField -> confirm ->
  webhook update status) atas device sebenar
- [ ] Webhook belum register di Stripe Dashboard (`STRIPE_WEBHOOK_SECRET`
  masih kosong) — perlu `stripe listen --forward-to
  localhost:8080/webhooks/stripe` untuk test lokal, atau daftar endpoint
  awam untuk staging/prod
- [ ] Threshold RM500 (Stripe vs SociaBuzz) belum implement —
  `DonationHandler.selectGateway` di backend sekarang SELALU pulang
  Stripe tak kira amount
- [ ] SociaBuzz — belum research API/webhook capability langsung
- [ ] ToyyibPay (yuran ahli, gate akses feed) — belum start
- [ ] Apple Pay / Google Pay — sengaja dilangkau buat masa ni (guna
  `CardFormField` asas, bukan `PaymentSheet`, elak setup merchant ID
  tambahan)
- [ ] Widget/integration test untuk `donation_page.dart` — setakat ni
  cuma `flutter analyze` bersih, belum ada automated test
