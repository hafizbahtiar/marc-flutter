# ToyyibPay — Setup & Reference

Status: **gateway kod siap + disahkan sandbox** (`marc_go/internal/payment/
toyyibpay.go`), **belum diwiring** ke handler/route. Dua guna kes
disahkan 2026-08-15:

1. **Yuran pendaftaran ahli — SEKALI BAYAR.** Dikenakan semasa proses
   daftar ahli baharu, BUKAN yuran berulang/dues berterusan. Ahli sedia
   ada (approved sebelum ciri ni wujud) dijangka dikecualikan — perlu
   disahkan eksplisit sebelum kod ditulis (lihat `../marc_go/TODO.md`).
2. **Yuran aktiviti berbayar** — sambung ke cangkuk sedia ada
   `activities.fee_cents`/`activity_registrations.payment_status` dalam
   `marc_go` (lihat "Modul Aktiviti — jurang yang tinggal" di
   `../marc_go/TODO.md`).

**BUKAN** skop ToyyibPay: donation <RM500 (itu `SociaBuzz`, gateway
BERASINGAN, belum diresearch — lihat `PAYMENT-STRIPE.md`). Versi awal
dokumen ni (sesi 2026-08-15 pertama) silap gabungkan dua-dua; dibetulkan
di sini.

## Nota sumber — bukan dibaca terus dari `apireference/`

`toyyibpay.com` sekat fetch terus (403, kemungkinan bot-blocking) semasa
kajian dibuat. Penemuan di bawah silang rujuk komuniti + panduan pihak
ketiga (fajarhac.com, cartdna.com) + carian enjin carian atas laman
rasmi — **BUKAN** dibaca terus dari `apireference/`. Sahkan semula
bila dah ada akaun dashboard sebenar sebelum kunci reka bentuk akhir.

## Kenapa ToyyibPay (bukan sambung Stripe FPX)

Backend (`marc_go`) sekat FPX Stripe sebab akaun perlukan **BRN** (Business
Registration Number) — akaun semasa `individual` tanpa BRN, tiada
keupayaan `fpx_payments` (lihat `../marc_go/TODO.md`, bahagian Payment).

ToyyibPay **disahkan** terima pendaftaran individu/peribadi **tanpa SSM**,
melalui pendaftaran bawah "Dewan Ekonomi GIG Malaysia" (DEGM, sebuah
pertubuhan berdaftar), bila guna **akaun bank peribadi**. SSM cuma perlu
kalau daftar dengan akaun bank syarikat. Ini mengesahkan sebab asal
ToyyibPay dipilih dalam perbincangan produk sebelum ni.

## Auth & setup akaun

- **`userSecretKey`** — kunci rahsia akaun (dashboard, bawah kiri).
  Padanan konsep dengan secret key Stripe.
- **`categoryCode`** — "kategori" bil, dicipta SEKALI melalui
  `createCategory` (`catname`, `catdescription`, `userSecretKey`), lepas
  tu dirujuk pada SETIAP bil. Bukan langkah per-request — setup sekali,
  simpan `categoryCode` dalam config.
- **Base URL**: produksi `https://toyyibpay.com/index.php/api/...`,
  sandbox `https://dev.toyyibpay.com/index.php/api/...` — bentuk sama,
  tukar host sahaja.
- **Sandbox**: daftar berasingan di `dev.toyyibpay.com` — akaun/kredential
  lain daripada produksi, ada simulator bank untuk bil ujian.

## Create bill (mulakan bayaran)

- `POST /index.php/api/createBill`
- `billAmount` dalam **sen** (RM1 = 100) — padan terus konsep
  `amount_cents` yang backend dah guna untuk Stripe, tiada penukaran unit
  diperlukan.
- Medan lain: `billName`, `billDescription` (had panjang tak
  didokumentasikan dalam sumber yang dibaca — anggap defensif macam
  metadata Stripe, jangan hantar teks panjang tanpa had), `billPriceSetting`
  (0=pembayar isi sendiri, 1=tetap — guna 1), `billPaymentChannel`
  (0=FPX sahaja, 1=kad sahaja, 2=dua-dua), `billReturnUrl`,
  `billCallbackUrl`, `billExternalReferenceNo` (letak rujukan dalaman kita
  di sini), `billTo`/`billEmail`/`billPhone`.
- Respons pulang **bill code**; halaman checkout/redirect ialah
  `https://toyyibpay.com/{billcode}` (atau host `dev.` untuk sandbox).
  **Sentiasa https** — serasi dengan semakan `scheme == 'https'` yang
  `RedirectCheckoutHandler` di `lib/features/donation/donation_gateway.dart`
  dah kuatkuasakan (lihat TODO.md audit 2026-08-15).

## ⚠️ Isu reka bentuk paling kritikal: sah callback kriptografi TAK BOLEH DIPERCAYAI

Kajian asal (2026-08-15, sesi 1) kata tiada mekanisme sah langsung.
**Kajian susulan (2026-08-15, sesi 2)** jumpa medan `hash` disebut dalam
sumber komuniti/kod sumber terbuka — TAPI dua sumber sekunder bagi
**formula berbeza**:

1. `md5(userSecretKey + status + order_id + refno + "ok")` — daripada
   ringkasan carian, sumber asal tak dapat disahkan.
2. `md5(secretKey + status_id + order_id + transaction_id + msg)` —
   daripada kod sumber terbuka `woo-toyyibpay` (plugin WooCommerce pihak
   ketiga, GitHub `Bomstart/woo-toyyibpay`), nampak khusus untuk callback
   DuitNow QR (medan `status_id`/`transaction_id`/`msg` padan senarai
   medan DuitNow QR, bukan callback FPX/kad biasa yang guna
   `status`/`refno`).

**Kesimpulan**: dua formula bercanggah daripada sumber tak rasmi, dan
tiada pengesahan `hash` hadir pada SEMUA jenis callback (nampak khusus
DuitNow QR). Ini TAK CUKUP boleh dipercayai untuk kawalan keselamatan
kewangan. Reka bentuk `ToyyibPayGateway` (kod dah ditulis, lihat bahagian
"Status kod" di bawah) sengaja **TIDAK** bergantung pada `hash` langsung
— body callback cuma diambil `billcode`, status sebenar disahkan semula
dengan poll `getBillTransactions` (guna `userSecretKey` sisi pelayan).
Ini selamat tak kira formula `hash` yang mana betul, atau kalau ia
langsung tak wujud untuk sesetengah kaedah bayaran.

Callback POST asal (FPX/kad): `status`, `billcode`, `order_id`, `refno`,
`amount` — boleh dipalsukan sesiapa yang tahu bentuk body, kalau
dipercayai mentah-mentah tanpa poll-confirm di atas.

**Kesan pada backend** (`marc_go/internal/http/handlers/donations.go`):
endpoint `Webhook` sedia ada ialah route **AWAM tanpa auth** yang
percaya SEPENUHNYA pada `Gateway.VerifyWebhook`. Untuk ToyyibPay,
`VerifyWebhook` **tak boleh** jadi pure/local check macam Stripe (HMAC
tempatan, tiada network call) — ia MESTI buat outbound call ke
`getBillTransactions` (guna `userSecretKey`) untuk sahkan status
SEBENAR sebelum credit apa-apa, bukan percaya body callback terus.

Ini penyimpangan tulen daripada kontrak `payment.Gateway` sedia ada, bukan
butiran pelaksanaan — perlu keputusan reka bentuk eksplisit di sisi
`marc_go` sebelum kod ToyyibPay ditulis. **Bukan skop dokumen Flutter
ni** — dicatat di sini supaya tak dilupa bila kerja bermula, butiran
pelaksanaan di `../marc_go/TODO.md`.

- Return URL (redirect browser lepas pembayar selesai) bawa GET params
  `status_id` (1=berjaya, 2=pending, 3=gagal), `billcode`, `order_id`.
  Ini **user-facing sahaja** — jangan sesekali dipercayai untuk credit.

## Idempotency / replay

Tiada token dedup daripada ToyyibPay sendiri. `getBillTransactions`
(`POST /index.php/api/getBillTransactions`, param `billCode` +
penapis pilihan `billpaymentStatus`) jadi endpoint pull/sahkan DAN
pengawal idempotency — sama pola macam sekarang: klausa WHERE status
belum-terminal pada `UpdateDonationStatusByGatewayRef` buat callback
berulang jadi no-op.

## Tiada subscription native (tak relevan lagi — nota sejarah)

API teras `createBill` **sekali sahaja**, tiada objek subscription, tiada
endpoint caj berulang. Satu panduan pihak ketiga (cartdna.com) sebut ciri
"direct debit" untuk kutipan berulang, tapi **tak dapat disahkan** menerusi
dokumentasi API rasmi — mungkin produk/aturan bank berasingan, bukan
primitif API yang boleh dipanggil. **Anggap tak disahkan.**

**Kenapa ni dah tak jadi isu**: keputusan produk 2026-08-15 sahkan
kedua-dua guna kes ToyyibPay (pendaftaran ahli, yuran aktiviti) ialah
**sekali bayar**, bukan berulang — jadi ketiadaan subscription native
bukan halangan reka bentuk lagi. Nota ni dikekalkan sebab ia jawapan
konkrit kepada soalan "kenapa bukan subscription" kalau timbul semula.

## Saluran bayaran & fi

- **FPX** dan **kad** disahkan sebagai dua nilai `billPaymentChannel`
  dalam API teras.
- **DuitNow QR** disebut dalam bahan pemasaran/panduan merchant ToyyibPay
  sendiri sebagai disokong, tapi bukan nilai `billPaymentChannel` peringkat
  pertama dalam dokumentasi createBill yang dibaca — berkemungkinan
  didayakan per-akaun/tier, bukan per-bil. Sahkan di dashboard.
- **Fi** (daripada ringkasan halaman harga, tak disahkan rasmi): FPX B2C
  ~RM1.00/transaksi (percuma untuk NGO), FPX B2B ~RM2.00/transaksi. Ada
  tier peratusan (1.5%/3.5%) untuk kaedah lain (kad?) — pemetaan
  pelan-ke-fi tepat tak dapat disahkan (laman harga rasmi 403). **Semak di
  dashboard sebelum letak apa-apa fi dalam salinan produk.**

## Disahkan hujung-ke-hujung terhadap sandbox sebenar (2026-08-15, sesi 3)

Bukan lagi andaian daripada sumber tak rasmi sahaja — `createBill` dan
poll `getBillTransactions` dua-dua dipanggil betul-betul terhadap
`dev.toyyibpay.com` guna akaun sandbox sebenar. Dua bug dijumpai (dan
dibaiki dalam `toyyibpay.go`) yang tiada dalam mana-mana sumber komuniti
yang dibaca sebelum ni:

1. **`billTo` wajib.** `createBill` pulang `{"status":"error","msg":
   "billTo parameter is empty"}` kalau tiada — bukan pilihan macam
   dokumentasi komuniti implikasikan.
2. **`getBillTransactions` pulang teks BIASA `"No data found!"`** (bukan
   array JSON kosong `[]`) bila tiada transaksi lagi untuk bil tu.

`createBill` sendiri (bentuk respons array `{"BillCode": "..."}`)
disahkan **betul** — `CreatePayment` diuji sebenar, dapat bill code sah +
`RedirectURL` yang boleh dibuka.

**Masih tak disahkan**: bentuk respons `getBillTransactions` bila bil
BERJAYA DIBAYAR (`billpaymentStatus="1"`) — perlu selesaikan satu
pembayaran ujian sebenar (simulator bank sandbox) untuk sahkan medan
tepat sebelum guna produksi.

## Status kod

- [x] `marc_go`: `internal/payment/toyyibpay.go` — `ToyyibPayGateway`
      implement `payment.Gateway` penuh, disahkan sandbox sebenar.
- [x] **Guna kes 1 (yuran pendaftaran ahli) DIWIRING PENUH, 2026-08-15
      sesi 4.** Migration `registration_payments`, handler
      `RegistrationPaymentHandler` (`Checkout`/`Webhook`/`ReturnPage`),
      gate pada `ApproveMember` (`setMemberStatus` tolak kalau belum
      bayar), route `POST /registration-payments/checkout` (RequireAuth
      sahaja), `POST /registration-payments/webhook/toyyibpay` +
      `GET /registration-payments/return/toyyibpay` (awam). Butiran
      penuh: `../marc_go/TODO.md` bahagian Payment. `go build`/`go vet`/
      `go test ./...`/`gofmt -l .` semua lulus.
- [ ] **`marc_flutter`: TIADA UI lagi.** Backend `Checkout` sedia (pulang
      `{"redirect_url": ...}`), tapi tiada skrin dalam aliran daftar/
      skrin pending yang panggil ia. `RedirectCheckoutHandler` sedia ada
      (https-only sejak audit 2026-08-15) sepatutnya boleh terus pakai
      untuk buka `redirect_url` ni — perlu skrin baharu (cadangan: dalam
      `_PendingStatusView`, `feed_page.dart`, papar butang "Bayar Yuran
      Pendaftaran" kalau belum bayar) yang panggil endpoint checkout
      lepas tu.
- [ ] Selesaikan SATU pembayaran ujian sebenar (simulator bank sandbox)
      untuk sahkan bentuk respons `getBillTransactions` bila
      `billpaymentStatus="1"` (berjaya) — satu-satunya kes API yang
      tinggal tak disahkan.
- [ ] `REGISTRATION_FEE_CENTS` sebenar (default kod 1000/RM10 ialah
      placeholder teknikal, bukan angka yang management setuju).
- [ ] **Guna kes 2 (yuran aktiviti) BELUM dibina** — keputusan reka
      bentuk berasingan diperlukan (lihat `../marc_go/TODO.md`, corak
      sama macam guna kes 1 tapi titik gate berbeza —
      `activity_registrations.payment_status`, bukan `profiles.status`).
- [ ] Threshold RM500 (Stripe vs ToyyibPay untuk donation <RM500) belum
      wired — `selectGateway` di `donations.go` sentiasa pulang Stripe.
      **Nota**: `ToyyibPayGateway` sekarang hardcode `billName`
      "Yuran MARC" — kalau nak reuse gateway sama untuk donation
      kelak, `billName`/description perlu jadi parameter.
