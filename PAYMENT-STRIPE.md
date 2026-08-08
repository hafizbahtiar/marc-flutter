# Stripe Donation — Setup & Reference

Status: **backend + Flutter UI done (PaymentSheet + FPX), belum diverify
end-to-end lawan Stripe sebenar** (test keys dah ada dlm `.env`
kedua-dua repo). Ni bahagian **Stripe sahaja** drpd payment module
(Stage 12) — yuran ahli (ToyyibPay) dan donation <RM500 (SociaBuzz)
**belum start**, lihat "Yang belum" di bawah dan `marc_go/TODO.md`
Stage 12 untuk gambaran penuh.

## Kenapa dua akaun berasingan

- **ToyyibPay** — akaun rasmi MAIWP (non-profit), untuk yuran ahli. Bukan
  skop dokumen ni.
- **Stripe** — akaun **peribadi** (pemaju app), khas untuk "Donate to
  us". Amount ≥RM500 guna Stripe; <RM500 akan guna SociaBuzz (belum
  wired). Currency **MYR sahaja** — elak isu penukaran mata wang.

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

**Stripe Dashboard**: FPX kena di-enable manual di Settings → Payment
methods — bukan sesuatu code boleh buat, langkah kau.

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
lib/features/donation/donation_gateway.dart    -- DonationCheckoutHandler + StripeCheckoutHandler (PaymentSheet) / RedirectCheckoutHandler
lib/features/donation/donation_providers.dart  -- handler registry, DonationRepository
lib/features/donation/donation_page.dart       -- form -> checkout -> handler.handle()
lib/app/stripe.dart                             -- init Stripe.publishableKey + urlScheme (no-op kalau kosong)
lib/app/theme.dart                              -- AppTheme.light/dark + AppSemanticColors
lib/core/theme_mode_provider.dart               -- ThemeMode toggle, persisted
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

## Yang belum (lihat `marc_go/TODO.md` Stage 12 untuk detail penuh)

- [ ] **Verify end-to-end lawan Stripe sebenar** — test keys dah masuk
  `.env`, belum run full flow (checkout -> PaymentSheet -> confirm ->
  webhook update status) atas device sebenar, termasuk test FPX redirect
  round-trip sebenar (bukan setakat kad)
- [ ] Enable FPX di Stripe Dashboard (Settings → Payment methods) — kau
  punya langkah, bukan code
- [ ] Webhook belum register di Stripe Dashboard (`STRIPE_WEBHOOK_SECRET`
  masih kosong) — perlu `stripe listen --forward-to
  localhost:8080/webhooks/stripe` untuk test lokal, atau daftar endpoint
  awam untuk staging/prod
- [ ] Threshold RM500 (Stripe vs SociaBuzz) belum implement —
  `DonationHandler.selectGateway` di backend sekarang SELALU pulang
  Stripe tak kira amount
- [ ] SociaBuzz — belum research API/webhook capability langsung
- [ ] ToyyibPay (yuran ahli, gate akses feed) — belum start
- [ ] Widget/integration test untuk `donation_page.dart` — setakat ni
  cuma `flutter analyze` bersih, belum ada automated test
