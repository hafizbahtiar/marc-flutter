# MARC Flutter — TODO

Kerja yang **belum siap** sahaja. Sejarah penuh ada dalam git log.
Corak wajib + gotcha platform: [`README.md`](./README.md).
Aliran donation Stripe: [`PAYMENT-STRIPE.md`](./PAYMENT-STRIPE.md).
Aliran ToyyibPay (kajian API siap, kod belum): [`PAYMENT-TOYYIB.md`](./PAYMENT-TOYYIB.md).
Backend: `../marc_go/TODO.md`.

---

## Ciri belum start

- [ ] **Onboard ahli lama (kertas/manual) ke app — BRAINSTORM BELUM
      SIAP, belum ada spec/plan.** Ahli sedia ada yang dah daftar, dah
      bayar, dan dah ada no. ahli (format LAMA, bukan `MARC{YYYY}/{MM}/
      {seq}` app) secara manual/kertas sebelum app ni wujud. Rujuk
      `../marc_go/TODO.md` bahagian sama untuk reka bentuk sisi backend
      (jadual `legacy_members`, medan `profiles.legacy_member_id`/
      `registration_fee_exempt`) — bahagian Flutter (medan "No. Ahli
      Lama" pilihan pada skrin daftar, mesej ralat bila no. tak
      dijumpai) BELUM direka lagi, sesi brainstorm terhenti sebelum
      sampai ke situ.

      **Keputusan disahkan (Q&A dgn pemilik produk, 2026-08-16):**
      - Skala: ~ratusan ahli lama.
      - Format no. ahli lama: **belum pasti** — pemilik produk akan
        tanya client. Reka bentuk kekal agnostik format (rentetan
        legap, TIADA parsing/validasi struktur).
      - Ahli lama LANGSUNG skip yuran pendaftaran ToyyibPay (dah bayar
        manual sebelum ni).
      - Cara claim: medan "No. Ahli Lama" PILIHAN pada skrin daftar
        (bukan kod jemputan, bukan padanan manual management
        selepas). App cari padanan dlm senarai diimport; management
        sahkan padanan tu betul semasa langkah kelulusan sedia ada.
      - Import senarai lama: **one-off sahaja** (client hantar satu
        senarai muktamad) — tak perlu UI import berulang.
      - No. ahli tak dijumpai dlm senarai → **sekat submission**, ralat
        jelas, user boleh cuba lagi ATAU kosongkan medan & daftar
        sebagai ahli baharu biasa (bayar yuran macam biasa).

      **Belum diputuskan / belum dibincang:**
      - Bentuk medan + UX skrin daftar Flutter sebenar.
      - Macam mana skrin kelulusan management (pending members) papar
        padanan rekod lama untuk semakan admin sebelum lulus.
      - Kes pertindihan (dua orang cuba claim no. ahli sama serentak).
      - Sama ada perlu ubah `profile_page.dart`/paparan member_id lain
        untuk kes format lama yang berbeza panjang/corak drpd format
        app.

- [x] **ToyyibPay: yuran pendaftaran ahli (sekali bayar) + yuran
      aktiviti berbayar — UI checkout DIBINA DAN DIWIRING** (disahkan
      2026-08-24, dah wujud dalam kod sebelum ni — TODO ni je yang lapuk,
      tiada kerja tambahan diperlukan). **BUKAN** "yuran ahli
      berulang"/dues (framing lama dibetulkan 2026-08-15, sesi 3).

      **Yuran pendaftaran**: `_PendingStatusViewState._payRegistrationFee`
      (`lib/features/posts/feed_page.dart`) — butang "Bayar Yuran
      Pendaftaran"/"Cuba Bayar Semula" dalam `_PendingStatusView`,
      `_PaymentStatusChip` papar status (pending/succeeded/failed).
      `RegistrationPaymentRepository.checkout()`
      (`lib/features/registration_payment/registration_payment_providers.dart`)
      panggil `POST /registration-payments/checkout`, tangkap
      `PhoneRequiredException` (ahli lama tiada phone) → dialog minta
      nombor → checkout semula.

      **Yuran aktiviti**: `_RegistrationCardState._payActivityFee`
      (`lib/features/activities/my_activities_page.dart`) — butang
      "Bayar Yuran Aktiviti" pada kad pendaftaran bila `feeUnpaid`.
      `activityRepositoryProvider.checkoutPayment(activityId)` corak
      sama (`PhoneRequiredException` → dialog → checkout semula).

      Kedua-dua tapak guna corak SAMA: `Uri.tryParse` + skim `https`
      sahaja (padan `RedirectCheckoutHandler` di `donation_gateway.dart`)
      → `launchUrl(..., LaunchMode.externalApplication)` → snackbar
      "selesaikan dalam pelayar, tekan Semak semula/tarik segar".
      Pengesahan sebenar async via webhook backend — client tak pernah
      tahu "berjaya" terus.

      `flutter analyze` bersih pada ketiga-tiga fail (disahkan
      2026-08-24). **Belum ada widget test khusus** untuk dua aliran ni.
      **Belum disahkan pada peranti sebenar** — checkout ToyyibPay,
      redirect balik, dan "Semak semula" tak pernah dilihat mata (padan
      nota "tak pernah dijalankan pada peranti" untuk Modul Aktiviti di
      bawah).

      **Diekstrak ke `CheckoutPage` reusable, 2026-08-24.** Logik
      checkout (phone-prompt, panggil `onCheckout`, validasi URL
      https-only, `launchUrl`, snackbar) sebelum ni diduplikasi PENUH
      dalam `_PendingStatusViewState._payRegistrationFee`
      (`feed_page.dart`) dan `_RegistrationCardState._payActivityFee`
      (`my_activities_page.dart`). Kini satu tempat sahaja:
      `lib/features/checkout/checkout_page.dart` — `CheckoutRequest`
      (title, amountCents, currency, description?, `onCheckout`
      callback generik) + `CheckoutPage` (route `/checkout`, `state.extra`
      — pertama kali `extra` dipakai dalam codebase ni, sebab
      `onCheckout` closure tak boleh jadi path param). Caller (dua
      tapak di atas) kini cuma `context.push('/checkout', extra:
      CheckoutRequest(...))` — tiada state checkout tempatan lagi,
      `_PendingStatusView`/`_RegistrationCard` bertukar
      `ConsumerStatefulWidget` → `ConsumerWidget` (buang `_submitting`/
      `_paying`, tak diperlukan lagi sebab navigasi sync). Lepas
      `launchUrl` berjaya, `CheckoutPage` `pop()` balik ke skrin asal —
      skrin asal yang uruskan "Semak semula"/pull-to-refresh, `CheckoutPage`
      sendiri tak pantau status.

      Reusable untuk module lain kelak (sebab asal permintaan ni):
      caller mana-mana pun boleh `context.push('/checkout', extra:
      CheckoutRequest(...))` tanpa `CheckoutPage` tahu apa-apa pasal
      ToyyibPay/registration/activity — ia cuma panggil `onCheckout`.

      **Widget test baharu**: `test/features/checkout/checkout_page_test.dart`
      (6 kes — jumlah/description terpapar, checkout berjaya + pop,
      URL bukan-https ditolak, `PhoneRequiredException` → dialog →
      checkout semula, nombor tak sah, ralat generik). Guna fake
      `UrlLauncherPlatform` (`extends`, bukan `implements` — constructor
      asal `super(token: _token)` yang lulus `PlatformInterface.verify`)
      — pertama kali pattern ni dipakai dalam test suite. Tambah
      `url_launcher_platform_interface` sebagai dev_dependency eksplisit
      (`pubspec.yaml`) — sebelum ni transitive sahaja.

      `flutter analyze` bersih, 251/251 ujian lulus (245 asal + 6
      baharu). Ni isi jurang "belum ada widget test khusus" yang
      dicatat di atas.

      **Opus verify 2026-08-24 (scoped kepada perubahan checkout ni)**:
      SAFE TO SHIP, tiada blocking finding. 4 isu non-blocking dijumpai
      dan KESEMUANYA DIBAIKI serta-merta:
      - **"MYR 0.00" mengelirukan bila medan `fee_cents` tiada dalam
        respons backend lama** (version skew — build baharu bercakap
        dgn API lama/rollback). `CheckoutRequest.amountCents` dan
        `MyRegistration.feeCents` ditukar `int` (lalai 0) →  `int?`
        (lalai `null`) — "tak diketahui" dan "percuma" tak boleh
        digabung. `CheckoutPage` sorok baris jumlah bila `null`, butang
        aktiviti sorok jumlah dalam label sama.
      - **`/checkout` boleh dicapai via deep-link `marc://...` dengan
        `extra` null/salah jenis** (skim `marc` didaftar utk Stripe
        redirect, `flutter_deeplinking_enabled` lalai ON) — crash
        `state.extra!` tak ditangkap `errorBuilder`. Dibaiki: `redirect:`
        pada `GoRoute` semak `state.extra is CheckoutRequest`, kalau
        tidak hala ke `/feed` (bukan crash). State restoration selepas
        process-death BUKAN laluan sebenar (tiada `restorationScopeId`
        dikonfigur mana-mana, app cold-start di `/login`) — deep-link
        satu-satunya laluan sebenar.
      - **`ref` (WidgetRef) tertangkap dalam closure `onCheckout` yang
        escape ke route lain** — kalau `_PendingStatusView`/
        `_RegistrationCard` dibuang (cth status ahli bertukar di latar
        semasa `CheckoutPage` terbuka) sebelum ahli tekan "Bayar
        Sekarang" DI SANA, `ref.read(...)` lewat tu boleh kena widget
        dilupuskan. Kesan kosmetik sahaja (jatuh ke snackbar ralat
        generik `_pay`'s catch), tapi dibaiki: baca repo (`ref.read(...)`)
        SEKARANG dalam `onPressed` (tapak butang mesti masih `mounted`
        semasa ditekan), closure `onCheckout` rujuk objek repo terus
        (bukan `ref` lagi) — objek repo tak terikat lifecycle widget.
      - **Jurang liputan ujian**: `_FakeUrlLauncher.shouldSucceed=false`
        tak pernah diuji (cabang `opened == false`), dan tiada assertion
        `LaunchOptions.mode == externalApplication` (regresi ke
        `inAppWebView` akan lulus senyap). Dua ujian baharu ditambah —
        total kini 253/253 lulus (251 + 2).

      **Invoice breakdown (Yuran + Caj Pemprosesan Pembayaran = Jumlah),
      2026-08-24** — permintaan produk: `CheckoutPage` kini pecah jumlah
      kepada baris "Yuran" (`amountCents - gatewayChargeCents`) + "Caj
      Pemprosesan Pembayaran" (`gatewayChargeCents`) + garis pemisah +
      "Jumlah Perlu Dibayar" (bold). `amountCents` (jumlah SEBENAR yang
      dihantar ke gateway) **TAK disentuh** — cuma paparan dipecah.

      **Backend**: `GATEWAY_CHARGE_CENTS` config baharu (`internal/config/
      config.go`, lalai 100 sen/RM1 — PLACEHOLDER, lihat blocker di
      bawah), endpoint baharu `GET /payment-config` (`protected`,
      `RequireAuth` sahaja, tiada rate limiter — bacaan statik, tiada
      DB) pulang `{"gateway_charge_cents": N}`. **Generik** — SATU sumber
      untuk SEMUA checkout (pendaftaran, aktiviti, modul depan), bukan
      duplikasi ke `/me`/`ListMyRegistrations`.

      **Flutter**: `lib/features/checkout/checkout_providers.dart`
      (`paymentConfigProvider`, `.autoDispose` — lihat nota Opus di bawah
      — TAK PERNAH throw, `catch` senyap fallback `kDefaultGatewayChargeCents
      = 100`). `_InvoiceCard`/`_InvoiceRow` dalam `checkout_page.dart`
      papar breakdown HANYA bila `amountCents > gatewayChargeCents`;
      kes tepi (≤ caj gateway, atau `amountCents` null) papar "Jumlah
      Perlu Dibayar" sahaja — elak "Yuran RM0.00"/negatif yang
      mengelirukan.

      **Opus verify 2026-08-24 (breakdown ni)**: NEEDS FIXES. 2 isu
      code-level DIBAIKI serta-merta:
      - Ujian `checkout_page_test.dart` guna `gatewayChargeCents: 100`
        (SAMA dgn `kDefaultGatewayChargeCents`) — tak boleh bezakan
        "guna nilai fetch" drpd "kebetulan sama dgn fallback". Dibaiki:
        tukar ke 250 (RM2.50) + 4 ujian baharu
        `checkout_providers_test.dart` (respons sah, medan tiada,
        ralat network, 404 backend lama) — total 14 ujian modul
        checkout (10 asal + 4 baharu).
      - `paymentConfigProvider` (`FutureProvider` biasa) cache nilai
        FALLBACK sebagai "berjaya" SELAMA-LAMANYA sepanjang app run —
        ahli buka checkout sekali semasa offline, breakdown terperangkap
        pada anggaran RM1 walau internet pulih kemudian, tiada cara
        betulkan selain restart app. Dibaiki: `.autoDispose` — provider
        reset bila `CheckoutPage` ditutup (tiada listener), checkout
        seterusnya fetch semula dari awal.

      - [x] **Angka RM1 DISAHKAN 2026-08-24** — pemilik produk sahkan
            terus fi ToyyibPay sebenar ialah RM1 (bukan tier NGO
            percuma yang `PAYMENT-TOYYIB.md` cadangkan sebagai
            kemungkinan). `GATEWAY_CHARGE_CENTS=100` ditulis eksplisit
            dalam `.env`/`.env.example` (bukan bergantung default kod
            senyap lagi).
      - [x] **Kontradik dengan resit PDF — DISELESAIKAN 2026-08-24
            (opsyen (a): resit dipecah sama macam checkout).**
            `receipt.FeePayment` (`marc_go/internal/receipt/receipt.go`)
            tambah medan `GatewayChargeCents` — `drawFeeDetailsTable`
            sisip DUA baris baharu ("Yuran"/"Caj Pemprosesan Pembayaran")
            SEBELUM baris "Penerima", guna boundary SAMA dengan
            `CheckoutPage` (`AmountCents > GatewayChargeCents`, `>`
            ketat — elak "Yuran RM0.00"/negatif). Panel "JUMLAH DIBAYAR"
            (jumlah besar atas resit) **TAK berubah** — kekal papar
            jumlah PENUH, breakdown cuma tambahan pada jadual butiran.
            `PaymentsHandler` (`internal/http/handlers/payments.go`)
            terima `gatewayChargeCents int` baharu (wiring `router.go`),
            kedua-dua `RegistrationReceipt` DAN `ActivityReceipt` hantar
            nilai sama. **`DonationReceipt` TAK disentuh** — gateway
            Stripe berasingan, tiada kaitan fi ToyyibPay ni.

            Ujian baharu `internal/receipt/receipt_test.go`
            (`TestGenerateFeePDF`, `TestGenerateFeePDFTanpaBreakdown` —
            3 kes tepi: jumlah sama caj, jumlah kurang caj,
            `GatewayChargeCents` tak diisi). `go build`/`go vet`/
            `gofmt -l .` bersih, `go test ./...` PENUH lulus (semua
            pakej, termasuk `internal/http/handlers`).

            **Tiada perubahan email** — resit pendaftaran/aktiviti
            TAK PERNAH dihantar emel (PDF download on-demand sahaja
            via `GET /me/payments/.../receipt`); emel resit cuma wujud
            untuk donation (Stripe, gateway berasingan sepenuhnya,
            tiada kaitan RM1 ToyyibPay ni) — jadi tiada "email sending
            UI" untuk diselaraskan di sini.

      Displayed-vs-charged amount race (senarai papar jumlah lama,
      checkout endpoint caj jumlah SEMASA kalau `PATCH /activities/:id`
      berlaku antara dua panggilan) turut disemak — **diterima sebagai
      risiko rendah, bukan bug**: ToyyibPay punya halaman sendiri papar
      jumlah SEBENAR sebelum ahli commit bayar, dan resit snapshot
      `fee_cents_paid` daripada jumlah yang BENAR-BENAR dihantar ke
      gateway, jadi resit tak pernah tersasar walau papar-app lapuk
      seketika.

      **Jumlah (RM) DITAMBAH pada butang bayar, 2026-08-24.** Sebelum ni
      butang "Bayar Yuran Pendaftaran"/"Bayar Yuran Aktiviti" tak papar
      apa-apa jumlah — ahli tekan bayar tanpa tahu berapa sehingga
      dilontar keluar ke halaman ToyyibPay sendiri (di luar kawalan
      app). Backend (`marc_go`): `GET /me` kini pulang
      `registration_fee_cents` (cuma bila `status != 'approved'`, padan
      skop `registration_payment_status`; `profile.go` `ProfileHandler`
      terima `registrationFeeCents` baharu, router.go wiring), dan
      `ListMyRegistrations` (`queries/activity_registrations.sql`) kini
      pulang `fee_cents`/`currency`
      (`coalesce(r.fee_cents_paid, a.fee_cents)` — sama pola
      `GetMyActivityFeeByID`). Flutter: `Profile.registrationFeeCents`,
      `MyRegistration.feeCents`/`currency`, butang papar "Bayar Yuran
      Pendaftaran RM10.00" / "Bayar Yuran Aktiviti MYR 25.00". `go
      build`/`go vet`/`gofmt -l .` bersih, handler test lulus
      (`HANDLER_TEST_DB`); `flutter analyze` bersih, 245/245 ujian
      lulus. **Belum disahkan mata pada peranti sebenar.**

      SociaBuzz (<RM500, donation) ialah gateway **BERASINGAN**, belum
      diresearch — jangan keliru dengan ToyyibPay, dua guna kes/akaun
      berbeza.

## Keputusan produk — belum diputuskan

- [ ] **Bucket R2 boleh dibaca awam.** `R2_PUBLIC_URL` guna Public
      Development URL r2.dev: sebarang objek boleh diambil sesiapa yang ada
      URL, tanpa auth. Kunci UUID tak diteka — itu kekaburan, bukan kawalan
      akses. Untuk app ahli-sahaja yang simpan gambar ahli, gantinya
      presigned GET. Cloudflare juga kata r2.dev bukan untuk produksi.
- [x] ~~Hadkan dimensi upload~~ — **siap 2026-08-09**. `image_picker`
      kini `maxWidth`/`maxHeight` 2048 + `imageQuality: 95` (mengecilkan
      DIMENSI; kualiti sengaja kekal tinggi). Backend kuatkuasakan semula
      pada 4096 melalui `image.DecodeConfig` atas header 64KB — presigned
      URL membenarkan client menaikkan apa-apa terus ke R2, jadi semakan
      client sahaja tak memadai.
- [ ] **Kisah pembangun** (`_DeveloperStory` dlm `donation_page.dart` +
      perenggan dlm `about_page.dart`) ditulis daripada fakta yang kau beri.
      Baca dan tulis semula dalam suara kau sendiri.
- [ ] **Kebenaran En. Ezri.** Nama beliau kini dikreditkan dalam DUA skrin
      yang akan tersiar di Play Store. Sahkan beliau setuju dinamakan secara
      awam sebelum terbit — sekali app disiarkan, ia tak boleh ditarik balik
      daripada peranti yang dah pasang.

## Gambar profil — Flutter ✅

- `MemberAvatar` (`shared/widgets/`) — SATU widget untuk setiap avatar.
  Gambar via `AppNetworkImage` (cache + nyahkod dihadkan pada saiz papar
  sebenar), fallback huruf pertama, label semantik, boleh diketuk secara
  pilihan. `radius` memandu lukisan DAN lebar nyahkod.
- Enam tapak `CircleAvatar` buatan sendiri diganti: post_card,
  comment_tile, members_page, pending_members_page, profile_page,
  donation_page. (audit_page kekal `CircleAvatar` — itu lencana IKON
  tindakan, bukan avatar ahli.)
- `avatarUrl` ditambah pada `Profile`, `MemberRow`, `Author`.
- `AvatarService` — pilih (dikecilkan 512px/kualiti 95 waktu pilih, jadi
  bitmap penuh tak pernah masuk memori) → PUT R2 presigned → `PATCH /me`.
- `AvatarCropPage` — potong 1:1 guna editor `extended_image` (dah jadi
  kebergantungan). Tanpa potong, gambar landskap jadi muka terkerat dalam
  bulatan.
- Header profil: ketuk avatar → sheet (pilih/buang), lencana kamera
  sebagai affordance, spinner semasa sibuk, `membersProvider` di-invalidate
  supaya senarai ahli tak kekal papar avatar lama.

Ujian: fallback + tiada muat turun bila tiada URL, nama kosong tak ranap,
guna `AppNetworkImage` bila ada URL, radius memandu saiz, ketuk hanya bila
`onTap` diberi, label semantik; parsing `avatar_url` merentas ketiga-tiga
model termasuk kes medan tiada langsung.

- [ ] Ujian widget untuk aliran tukar avatar hujung-ke-hujung (pilih →
      potong → naik) — perlukan mock image_picker + Dio.
- [ ] Uji pada peranti sebenar: potong, naik, dan avatar muncul dlm feed.

## DuitNow QR (siap 2026-08-09)

QR peribadi Maybank dipapar pada halaman sokongan, dengan butang simpan ke
galeri (`gal`). **Stripe tak menyokong DuitNow langsung** — Malaysia dapat
FPX, GrabPay dan kad sahaja — dan gateway tempatan yang menyokongnya
(Billplz) perlukan akaun syarikat, jadi QR peribadi satu-satunya laluan.

Tukar ganti dinyatakan dalam UI: bayaran QR memintas backend, jadi tiada
baris `donations`, tiada resit PDF, tiada emel. Dilindungi ujian.

- [ ] Rekonsiliasi manual — tiada cara tahu siapa hantar berapa selain
      penyata bank. Kalau volum meningkat, pertimbang ToyyibPay (sokong
      DuitNow QR, terima akaun individu — sahkan dulu) sebagai
      `payment.Gateway` kedua; `RedirectCheckoutHandler` dah sedia.

## Penggubah post (refactor gaya Twitter) ✅

- Avatar penulis di sebelah medan teks — mengarang terasa macam melihat
  pratonton post sendiri, dan ia guna `MemberAvatar` yang sama dgn feed.
- Pratonton gambar guna susun atur SAMA dengan feed. `ImageGridLayout`
  diekstrak daripada `PostImageGrid` supaya kedua-duanya berkongsi
  peraturan 1/2/3/4 — sebelum ni penggubah papar jalur mendatar yang tak
  menyerupai hasil langsung.
- Pengumuman jadi **pil** (padanan pemilih khalayak Twitter), bukan
  `SwitchListTile` di atas penggubah.
- Butang Hantar **mati** bila tiada teks dan tiada gambar. Dulu ia
  menerima ketukan lalu membalas dgn snackbar ralat.
- Medan teks: autofocus, `maxLines: null` (tumbuh dgn kandungan), saiz
  `titleMedium`, hint yang lebih lembut.
- Kiraan gambar hanya muncul selepas gambar pertama; jadi merah pada had.
- Butang Hantar bentuk pil dgn `minimumSize` eksplisit — `filledButtonTheme`
  global set lebar TAK TERHINGGA, yang meletup dalam Row.
- **Tiada garisan pemisah, tiada isian medan.** `inputDecorationTheme`
  global set `filled: true` dgn `surfaceContainerHighest`, jadi
  `border: InputBorder.none` SAHAJA masih tinggalkan kotak kelabu —
  `filled: false` mesti eksplisit. Garisan atas bar penggubah pun dibuang;
  penggubah kini satu permukaan berterusan.
- **Galeri dan kamera berasingan** (macam Twitter), bukan satu ikon media.
  Tiada semakan permission_handler untuk kamera: image_picker melancarkan
  app kamera sistem melalui intent yang uruskan kebenarannya sendiri —
  mengisytiharkan CAMERA dalam manifest SEBALIKNYA akan memaksa permintaan
  runtime yang kita tak perlukan. iOS perlukan
  `NSCameraUsageDescription` (ditambah) atau app ranap bila kamera dibuka.

**Pepijat susun atur ditemui oleh ujian**: `Expanded` cuma mengekang paksi
utama, jadi jubin grid bersaiz ikut kandungan pada paksi silang — widget
tanpa saiz intrinsik runtuh jadi TINGGI SIFAR, dan gambar besar melimpah
keluar sel. Difix dgn `CrossAxisAlignment.stretch` pada semua Row/Column
dalam grid. Ini wujud dalam `PostImageGrid` sejak awal; ia cuma tak
kelihatan sebab gambar rangkaian kebetulan mengisi ruang.

## Modul Aktiviti — dibina, TAPI belum pernah dijalankan pada peranti

Feature folder `lib/features/activities/`:

| Fail | Skrin / peranan |
|---|---|
| `activities_page.dart` | senarai aktiviti (tab Akan Datang / Lepas) |
| `activity_detail_page.dart` | butiran + daftar / batal pendaftaran |
| `my_activities_page.dart` | pendaftaran sendiri + QR check-in |
| `my_certificates_page.dart` | senarai sijil + muat turun PDF |
| `checkin_qr.dart` | widget QR |
| `activity_models.dart` / `activity_format.dart` / `activity_providers.dart` | model, pemformatan tarikh, Riverpod |
| `manage/activity_form_page.dart` + `activity_draft.dart` | CRUD aktiviti + editor sesi |
| `manage/registrations_page.dart` | senarai pendaftar + tanda hadir |
| `manage/checkin_scanner_page.dart` + `scan_result.dart` | pengimbas QR |
| `manage/issue_certificates_page.dart` | terbit sijil |
| `manage/management_gate.dart` / `manage_providers.dart` | pengawal + Riverpod pengurusan |

### ⚠️ Tiada satu pun skrin ini pernah dijalankan pada peranti

204 ujian lulus, `flutter analyze` bersih, `flutter build apk --debug`
lulus. **Tiada satu pun daripada itu melihat piksel.** Yang khususnya
TIDAK disahkan:

- **Kamera tidak pernah dijalankan.** Tiada imbasan QR sebenar berlaku,
  gesaan kebenaran kamera tak pernah dilihat, susun atur pratonton
  `checkin_scanner_page` tak pernah dipaparkan.
- **QR belum pernah diimbas oleh pengimbas sebenar** — sama ada QR ahli
  dalam `checkin_qr.dart` mahupun QR pada PDF sijil. Saiz, kontras dan
  kuiet zon semuanya andaian.
- **Susun atur setiap skrin** dalam modul ni tak disahkan oleh mata
  manusia. Ujian widget mengesahkan kelakuan, bukan rupa.

- [ ] Larian menyeluruh pada peranti sebenar (Infinix X6833B ialah peranti
      yang sudah digunakan untuk aliran lain): cipta aktiviti → terbit →
      daftar → papar QR → imbas dengan telefon kedua → tanda hadir →
      terbit sijil → muat turun PDF → imbas QR pada PDF.
- [ ] Semak susun atur pada skrin kecil dan mod gelap. Latar QR sengaja
      dikunci putih di tiga tempat (QR gelap tak dapat diimbas), ada ujian
      mod gelap — tapi tetap belum pernah dilihat.

### Kebergantungan yang dipin, dan sebabnya

Siling projek ini ialah **compileSdk 35** — `permission_handler` dipin ke
12.0.3 kerana 13.x menarik transitive yang perlukan compileSdk 37. Sebab
penuh ada dalam komen `pubspec.yaml:52` (dan `:61-62`, `:67-72` untuk dua
pakej di bawah). Kedua-dua pakej modul aktiviti disemak terhadap siling itu:

- **`qr_flutter: ^4.1.0`** — disahkan **tiada folder `android/` atau
  `ios/`**: Dart tulen (`CustomPainter`), jadi mustahil ia menyentuh siling
  compileSdk 35. Laluan QR juga disahkan bebas-rangkaian.
- **`mobile_scanner: ^7.4.0`** — SATU-SATUNYA pakej dalam modul ni yang
  membawa kod Android/iOS asli, jadi satu-satunya risiko sebenar terhadap
  siling compileSdk 35. Versi TERKINI, bukan yang diturunkan: ini risiko
  terbesar dalam pelan (jangkaan: perlu turun versi) dan ia **lulus binaan
  pada percubaan pertama**, 74.7s, tanpa menyentuh `build.gradle.kts`.
  Kebenaran `CAMERA` disahkan wujud dalam manifest **TERGABUNG** (bukan
  diandaikan), dan `NSCameraUsageDescription` dalam `Info.plist`
  dikembangkan supaya menyebut kamera untuk gambar post DAN pengimbas.
  Kalau `mobile_scanner` perlu dinaik taraf kemudian, ulang semakan
  manifest tergabung — bukan hanya `flutter pub get`.

### Muat turun sijil melalui `url_launcher`, bukan storan tempatan

`GET /me/certificates/:id/file` memulangkan `{"url": "..."}` — URL R2
bertandatangan, bukan bait. `my_certificates_page` membukanya dengan
`launchUrl(..., LaunchMode.externalApplication)`. **Tiada apa-apa ditulis
ke storan peranti**: tiada kebenaran storan, tiada pengurusan fail, tiada
pembersihan. Tukar ganti: tanpa rangkaian, tiada sijil — dan pengguna
keluar daripada app ke pelayar/pemapar PDF sistem.

- [ ] Kalau "simpan sijil ke telefon" diminta, ia ciri BAHARU (muat turun
      + `share_plus`/`gal`), bukan pembetulan.

### Jurang yang diketahui dalam modul ni

- [ ] **Yuran aktiviti tiada UI langsung** — dan itu betul buat masa ni,
      sebab backend pun tiada gateway untuk aktiviti berbayar (lihat
      `../marc_go/TODO.md`, bahagian Modul Aktiviti). `feeCents` sengaja
      DIKECUALIKAN daripada `ActivityDraft` supaya ia tak pernah masuk ke
      dalam diff `PATCH` dan tak boleh ditulis ganti kepada 0 secara tidak
      sengaja. Bila payment mendarat, medan itu perlu ditambah pada draf
      DAN pada laluan pendaftaran.
- [ ] Senarai My Activities guna `ListView(children:)` bukan `.builder`,
      jadi setiap QR dibina walaupun di luar skrin — dan `QrImageView`
      jalankan `QrValidator.validate` (pengekodan Reed-Solomon, bukan
      bitmap dicache) setiap build. 30 pendaftaran = 30 pengekodan setiap
      rebuild. Belum diukur pada peranti, tapi ini calon pertama kalau
      skrin itu tersekat-sekat.
- [ ] QR duduk DALAM `InkWell` kad — sentuhan pada QR menavigasi keluar
      daripada kod yang sedang ditunjukkan kepada pengimbas.
- [ ] Tiada cache atas-cakera untuk senarai aktiviti/pendaftaran, jadi
      jaminan "boleh papar QR tanpa isyarat" **gagal pada cold start**.
- [ ] Setiap imbasan mencetuskan refetch senarai pendaftar penuh pada
      skrin di bawah: 40 orang = 40 GET tambahan yang bersaing dengan POST
      kehadiran pada wifi dewan.
- [ ] Toast KEGAGALAN imbasan tidak menamakan ahli, dan kegagalan lewat
      boleh menimpa kejayaan yang lebih baharu — operator akan mengaitkan
      merah itu dengan orang yang berdiri di depannya. Terbatas kerana
      imbas semula idempoten. Cadangan: jadikan toast mengenal diri
      (nama + sesi), bukan melengahkannya.
- [ ] Sesi yang hilang → backend 404 "sesi tidak dijumpai" dipetakan ke
      `unknownCode` dengan ikon `qr_code_2`, yang menuding operator ke
      telefon ahli sedangkan masalahnya pada aktiviti.
- [ ] Butang "Batal pendaftaran" masih aktif walaupun aktiviti
      `completed`/`cancelled`.
- [ ] Enam rentetan Melayu dalam laluan pendaftaran tiada liputan ujian
      widget (ujian memin enum `RegistrationBlocker` sahaja).
- [ ] **Status backend BAHARU akan dicorongkan senyap ke "belum dibuka".**
      `registrationBlocker` dalam `activity_models.dart` berakhir dengan
      catch-all `if (status != 'published') return
      RegistrationBlocker.notPublished`. Enum `RegistrationBlocker`
      melindungi **pemetaan** (switch tanpa `default`, jadi nilai enum
      baharu gagal KOMPIL) — ia tidak melindungi **klasifikasi**. Status
      pelayan yang tidak dikenali jatuh ke dalam catch-all itu tanpa
      sebarang amaran binaan.
      Ini bukan teori: `../marc_go/TODO.md` mencadangkan tepat perubahan
      yang akan mencetuskannya — sapuan yang akhirnya mengalihkan aktiviti
      ke `completed`, dan apa-apa status peralihan baharu yang datang
      bersamanya. Ubat: petakan status secara eksplisit dan jadikan yang
      tidak dikenali kes yang boleh dilihat, bukan lalai kepada
      "belum dibuka".

## Iklan dalam-feed (dirancang, belum start)

Matlamat: unit iklan yang duduk dalam feed dan padan dengan `PostCard`,
gaya promoted tweet.

**Dakwaan "tiada iklan" dah dibuang** daripada `_DeveloperStory` — jangan
masukkan semula.

### Yang penting daripada kajian (2026-08-09)

- **Pelabelan tak boleh dirunding.** FTC syorkan "Ad", "Advertisement",
  "Paid Advertisement" atau "Sponsored"; ia secara khusus KATA JANGAN guna
  "Promoted" sebab kabur. Label kena di ATAS atau SEBELUM tajuk, nampak
  tanpa sebarang interaksi.
- **Dasar AdMob**: teks "Ad"/"Sponsored" minimum 15px, tambah overlay
  AdChoices (SDK letak sendiri) yang mesti mudah dilihat. Dilarang:
  menyamarkan label/AdChoices, meletakkan kandungan app bertindih atas
  iklan, dan **ruang putih boleh diklik** (latar iklan mesti TAK boleh
  diklik).
- **Ketumpatan**: satu iklan setiap 5–10 item, pada selang yang boleh
  dijangka. Selang tetap lebih baik daripada rawak — pengguna belajar
  jangkaannya.
- **Ketegangan reka bentuk yang sebenar**: nasihat "seamless" bermaksud
  padankan tipografi/jarak/warna, BUKAN sorokkan yang ia iklan. Iklan yang
  betul-betul tak dapat dibezakan daripada post ahli melanggar dasar
  AdMob DAN garis panduan FTC.

### Kerja bila mula

- [ ] Pilih rangkaian. `google_mobile_ads` (AdMob) ialah lalai; native ad
      perlukan sama ada Native Templates (Dart sahaja, kurang kawalan) atau
      layout khusus Android+iOS (kod per-platform).
- [ ] Widget `SponsoredCard` yang kongsi metrik `PostCard` (avatar, jarak,
      radius) tapi bawa label "Iklan" yang jelas + AdChoices.
- [ ] Sisip dalam `feedProvider` setiap N item — pengiraan indeks mesti
      TAK mengganggu pagination keyset atau `patchPost`.
- [ ] Keputusan: iklan untuk semua, atau disembunyikan untuk ahli yang
      menyokong? (Kalau ya, itu jadi ciri langganan — dan dakwaan "tiada
      langganan" pula kena dibuang.)

**Sebelum melabur masa**: komuniti tertutup yang kecil menjana hasil iklan
yang sangat sedikit (fikir sen sebulan pada ratusan ahli). Berbaloi
banding dengan kos: gangguan UX, kelulusan dasar AdMob, dan SDK iklan yang
mengumpul data peranti ahli. Sumbangan mungkin sesuai dengan komuniti ni
lebih baik daripada iklan.

## Audit menyeluruh `lib/` (2026-08-15) — semua DIBAIKI

Audit Opus berskop penuh atas `lib/`. Direkod supaya tidak diburu semula
sebagai penemuan baharu — semua enam sudah dibaiki dan disahkan
(`flutter analyze` bersih, 219/219 ujian lulus).

- [x] **Storan token pecah kekal selepas Android backup/restore.**
      `TokenStorage` tiada `AndroidOptions` eksplisit → default
      `encryptedSharedPreferences: false`, dan `AndroidManifest.xml` tiada
      `allowBackup="false"` → fail token disandar Google cloud, dipulih ke
      peranti dengan kunci Keystore lain → setiap bacaan lepas itu throw
      `PlatformException` yang tersasar daripada catch block sedia ada →
      login gagal senyap selama-lamanya, satu-satunya pemulihan ialah clear
      app data. Dibaiki: `AndroidOptions(encryptedSharedPreferences: true,
      resetOnError: true)`, `allowBackup="false"`, `api_client.dart` dan
      `auth_service.dart` kini tangkap `PlatformException` khusus dan cuba
      `deleteAll()` + retry sekali sebelum mesej ralat generik.
- [x] **`RedirectCheckoutHandler` lancar URL tanpa sahkan scheme.** Latent
      (Stripe sahaja sekarang) tapi laluan sedia untuk ToyyibPay. Dibaiki:
      `Uri.tryParse` + semakan `scheme == 'https'` dalam
      `donation_gateway.dart` dan `my_certificates_page.dart`.
- [x] **ID notifikasi disuntik mentah ke route string.** `activityId`/
      `postId` boleh bawa `/`, `%`, `?`, `#`. Dibaiki: `Uri.encodeComponent`
      dalam `notifications_page.dart`.
- [x] **Debounce scanner catat cuba, bukan berjaya.** Kegagalan network
      buat pengimbas nampak beku 3 saat pada kod sama. Dibaiki:
      `ScanDebouncer.evict()` dipanggil bila `result.kind == network`.
- [x] **Banner scan papar `display_name` mentah** — nama panjang/multi-baris
      herot banner di pintu. Dibaiki: `_sanitizeName` (potong newline,
      truncate 40 aksara).
- [x] **Logout tak clear cache gambar disk.** Peranti kongsi warisi gambar
      ahli sebelumnya. Dibaiki: `clearMemoryImageCache()` +
      `clearDiskCachedImages()` dalam `signOut()`.

## Profile page diblok untuk ahli pending/rejected (2026-08-24) ✅

Permintaan pengguna: "kalau tak bayar yuran, profile page pun tak boleh
access macam page lain, cuma profile tambah button logout." Sebelum ni
cuma `FeedPage` blok ahli `pending`/`rejected` (`PendingStatusView`,
dulu private `_PendingStatusView`) — tab Profile tetap papar profil
penuh + Edit Profil + tukar avatar walau ahli belum diluluskan/bayar.

**Diekstrak jadi reusable**: `lib/shared/widgets/pending_status_view.dart`
(`PendingStatusView`, public — dulu private dalam `feed_page.dart`).
`feed_page.dart` diringkaskan (buang duplikasi `_PendingStatusView`/
`_PaymentStatusChip`, guna widget dikongsi). Tambahan baharu: parameter
`footer` (widget pilihan) untuk kandungan tambahan khusus caller.

**`profile_page.dart`** kini gate SEBELUM papar kandungan profil biasa
(`p != null && p.status != 'approved'`) — papar `PendingStatusView` yang
SAMA dengan Feed, tapi `footer:` diisi butang "Log Keluar"
(`_handleLogout` sedia ada, guna semula terus). `footer` WAJIB di sini
(tak macam Feed) — sebaik profile turut diblok, ahli yang SEMUA tab
diblok takkan ada jalan keluar akaun langsung tanpa butang ni (Profile
dulu SATU-SATUNYA tempat logout tinggal).

`flutter analyze` bersih, 259/259 ujian lulus (tiada regresi — tiada
widget test sedia ada untuk `ProfilePage`/`FeedPage` yang perlu
dikemas kini, konsisten dengan jurang ujian yang dicatat di bawah).

- [x] **Disahkan pada peranti sebenar 2026-08-24 — 1 bug SEBENAR
      dijumpai dan DIBAIKI.** Hot restart sebagai ahli `pending` dedah
      race semasa muat PERTAMA `myProfileProvider`: gate
      `if (profileStatus != null && ...)` (Feed) dan
      `if (p != null && ...)` (Profile) kedua-duanya guna
      `valueOrNull`, yang `null` SAMA ADA masih loading ATAU pernah
      error — jadi semasa loading pertama (belum PERNAH ada nilai),
      gate gagal terbuka dan Scaffold PENUH terpapar sekejap SEBELUM
      status sebenar sampai. Kesan konkrit: FAB "Cipta Post" (Feed) dan
      butang "Edit Profil" (Profile, di AppBar `actions`, tak macam
      avatar-tap yang sedia ada guard `p == null ? null : ...`) boleh
      ditekan oleh ahli pending dalam tetingkap singkat tu.

      Dibaiki KEDUA-DUA fail: tambah semakan eksplisit
      `profile.isLoading && !profile.hasValue` (muat PERTAMA, beza
      drpd `hasError` selepas cubaan pertama — itu KEKAL fail-open
      sengaja, komen sedia ada) → papar `Scaffold` neutral
      (`CircularProgressIndicator.adaptive()` sahaja, tiada FAB/action)
      SEBELUM gate status. `feed_page.dart`: `isInitialLoading`
      ditambah dalam tuple `.select()` sedia ada (kekal satu
      panggilan `ref.watch`, tak tambah rebuild baharu).
      `flutter analyze` bersih, 259/259 ujian lulus (tiada test khusus
      ditambah untuk race ni — perlukan kawalan timing `AsyncValue`
      dalam widget test, jurang yang sama dgn `ProfilePage`/`FeedPage`
      tiada widget test sedia ada, dicatat di bawah).
- [ ] **`ActivitiesPage`/`NotificationsPage` tak digate langsung** —
      skop permintaan ni cuma Feed + Profile. Ahli pending yang tekan
      tab lain masih papar skrin biasa (kosong/ralat sebab backend 403
      pada endpoint bergantung `RequireApprovedStatus`), bukan skrin
      blok yang konsisten. Sengaja tak disentuh — bukan diminta.

## Backend L32 (2026-08-22) — reset kata laluan ✅

Skrin `forgot_password_page.dart` baharu + pautan "Lupa kata laluan?" pada
`login_page.dart`. Flutter hanya mengumpul EMEL; kata laluan baharu ditaip
pada halaman `marc_astro` (tiada app-link https dikonfigur, jadi pautan
emel membuka pelayar).

⚠️ `forgotPasswordSentMessage` MESTI kekal neutral — backend pulang 204
sama ada akaun wujud atau tidak, dan mesej yang berkata "Pautan dihantar!"
akan membocorkan apa yang backend sengaja sembunyikan. Dikunci oleh ujian.

## Backend Integrasi Telegram Fasa 1 (2026-08-22) — binding akaun ✅

Bukan penemuan audit (tiada label `L##`) — ciri baharu dari brainstorm
berasingan. Spec: `../marc_go/docs/superpowers/specs/2026-08-22-telegram-binding-design.md`.
Fasa pertama drpd tiga (binding → notifikasi → 2FA); dua yg terakhir
BELUM dibina.

Dibuat:
- `Profile` (`profile_providers.dart`) tambah `telegramLinked`
  (required) + `telegramUsername` (nullable), dihurai drpd `/me`
- `telegram_link_page.dart` — skrin baharu, papar keadaan
  Sambung/Disambungkan + `@username` kalau ada, butang nyahikat
- `ListTile` "Telegram" dlm seksyen **Tetapan** `profile_page.dart`
  (BUKAN `about_page.dart` — itu laman rasmi/penafian)
- `AuthService.requestTelegramLinkToken()` /
  `AuthService.deleteTelegramLink()` — dua kaedah baharu
- Route `/telegram-link` dlm `router.dart`

⚠️ `telegramLinked` jadi param `required` baharu pd `Profile` —
kalau tambah tapak pembinaan `Profile(...)` baharu (test atau
production), WAJIB sertakan field ni, kalau tidak `flutter analyze`
gagal serta-merta (5 tapak ujian sedia ada dibetulkan semasa
laksana ciri ni).

Ciri ni MATI di backend (503) sehingga `TELEGRAM_BOT_TOKEN` diset
production/staging — belum diset lagi. Butang "Sambung Telegram"
akan papar mesej ralat sehingga itu, bukan crash.

## Backend L33 (2026-08-22) — derma dalam "Bayaran Saya" ✅

`GET /me/payments` kini memulangkan senarai KETIGA, `donations`
(`../marc_go/TODO.md` **L33**). Sebelum ni
`PaymentReceiptRepository.donation()` sudah wujud dan berfungsi — tapi
tiada pemanggil boleh sampai kepadanya, sebab ia perlukan `donations.id`
dan tiada permukaan API yang pernah mendedahkan id itu kepada pemiliknya.
Endpoint resit tak pernah rosak; senarainya yang tiada.

Dibuat:
- `DonationPaymentEntry` + medan `donations` pada `MyPaymentHistory`
- Seksyen "Sokongan" dalam `payment_history_page.dart` (diletak AKHIR:
  dua di atas kewajipan keahlian, ini sokongan sukarela)
- `_DonationTile` — bentuk padan `_RegistrationFeeTile` (jumlah sebagai
  tajuk), bukan `_ActivityFeeTile` (yang tajuknya nama aktiviti)
- Butang resit digate `status == 'succeeded'`, corak sama dua seksyen lain

⚠️ **`donations` dinyahsiri dengan `?? const []`** — bukan kemasan.
Semasa deploy berperingkat, app baharu boleh mencapai backend lama yang
belum menghantar kunci itu. Tanpa fallback, skrin "Bayaran Saya" mati
sepenuhnya sepanjang tetingkap tu. Dikunci oleh ujian
`test/features/payments/payment_models_test.dart`.

Derma TANPA NAMA tak muncul — penderma tiada akaun untuk menuntutnya,
dan emel resit semasa webhook satu-satunya jejak mereka, ikut reka bentuk.

## Backend L35 (2026-08-22) — jenis notifikasi baharu `comment_like` ✅

Backend kini menghantar `comment_like` bila seseorang menyukai komen ahli
(keputusan produk 2026-08-22, `../marc_go/TODO.md` **L35**). Ini **memang**
memerlukan perubahan Flutter — tak macam batch sebelumnya.

Kenapa ia tak boleh dibiarkan: `notifications_page.dart` memetakan jenis
secara EKSPLISIT dan jenis tak dikenali mendarat di `default`, yang
memanggil `assert(false, ...)`. Dalam binaan **debug/profile** itu
**crash** pada halaman notifikasi; dalam release pengguna nampak "Anda ada
notifikasi baharu." dan bukan ayat sebenar.

Dibuat:
- `notificationIcon` → `Icons.favorite` (kongsi cabang dgn `post_like`)
- `notificationColor` → `scheme.error` (kongsi cabang dgn `post_like`)
- `notificationTitle` → "Seseorang menyukai komen anda"
- `notificationDestination` **tidak** disentuh — ia berasaskan ID bukan
  jenis, dan `comment_like` membawa `post_id`, jadi ketukan sudah
  menghala ke post yang betul.

Turut ditangkap semasa itu: senarai kontrak `_jenisServer` dalam
`test/features/notifications/notifications_mapping_test.dart` sudah
terpesong — ia tertinggal **`activity_reminder`** (backend 2026-08-15)
walaupun switch memetakannya. Kedua-dua jenis ditambah ke senarai.

⚠️ Senarai itu ialah kontrak silang-repo dengan kekangan
`notifications_type_check` dalam migration `marc_go`. Bila migration
meluaskan kekangan, senarai ni MESTI diluaskan sama.

## Perubahan backend 2026-08-22 (batch terdahulu) — kesan pada Flutter: TIADA kod perlu diubah

Audit `marc_go` (`queries/`, `internal/`, `cmd/` — laporan penuh:
`../marc_go/docs/audits/2026-08-22-queries-internal-cmd.md`) menghasilkan
tujuh pembaikan. Semuanya disemak terhadap `lib/` sebelum dihantar.
**Tiada satu pun memerlukan perubahan Flutter.** Direkod di sini supaya
kontrak yang berubah tak ditemui secara terkejut kemudian.

**Disahkan selamat, tiada tindakan:**

- **`checkin_token` DIBUANG daripada `GET /activities/:id/registrations`**
  (L12). `manage_providers.dart` sudah menyatakan medan itu "SENGAJA tidak
  dimodelkan", jadi `ActivityRegistrant` tak pernah membacanya —
  itulah yang membolehkan backend membuangnya. Kini konvensyen klien tu
  dikuatkuasakan di pelayan.

  ⚠️ Ia **kekal** dalam `GET /me/activities` (`ListMyRegistrations`) —
  `my_activities_page.dart` melukis QR ahli daripadanya. Jangan andaikan
  medan itu hilang di semua tempat.

- **`PATCH /comments/:id` kini pulangkan `author` + `like_count` +
  `liked_by_me`** (L34, sebelum ni ketiga-tiganya nilai sifar).
  `editComment` (`post_providers.dart`) buang respons sepenuhnya dan
  `_ref.invalidate(commentsProvider)`, jadi pepijat itu **tak pernah
  kelihatan** kepada pengguna di klien ni — selamat secara kebetulan
  corak invalidate-refetch, bukan secara reka bentuk.

  Peluang (BUKAN keperluan): respons kini lengkap, jadi `editComment`
  boleh mengemas kini komen itu di tempatnya dan melangkau refetch
  senarai penuh. Cuma buat kalau latensi edit jadi masalah sebenar —
  invalidate lebih mudah dan tak boleh terpesong.

- **`WriteTimeout` backend 15s → 90s** (L31).

  ⚠️ **JANGAN buang `certificatesIssueTimeout` (5 minit) dalam
  `manage_providers.dart`.** Ia masih diperlukan, dan sekarang lebih
  berguna daripada sebelum ini.

  Siapa mengehadkan siapa, sebelum dan selepas:

  | | Klien (dio) | Pelayan (`WriteTimeout`) | Yang mengikat |
  |---|---|---|---|
  | Terbit sijil, dulu | 5 min | 15s | **pelayan** (~20 sijil) |
  | Terbit sijil, kini | 5 min | 90s | **pelayan** (~120 sijil) |
  | Selebihnya | 12s | 90s | **klien** |

  Jadi 90s itu menaikkan saiz kohort yang benar-benar mendapat respons
  daripada ~20 kepada ~120 sijil (fasa 2 berjujukan, ~0.7s sesijil).
  Melebihi itu, pelayan masih memutuskan dahulu dan pengurus masih
  bergantung pada laluan 202/timeout + "Tekan Terbitkan sekali lagi"
  yang sudah dibina — yang kekal betul dan kekal diperlukan.

  Siling itu hanya hilang sepenuhnya apabila fasa 2 jadi kerja latar di
  pelayan (kekal terbuka sebagai L31 dalam `../marc_go/TODO.md`).

  Laluan lain (resit, dsb) diikat oleh lalai dio 12s, bukan oleh pelayan
  — tidak berubah, dan tidak terjejas.

- L13 (kolam sambungan), L28 (reaper), L29 (log bil yatim), L30 (tingkap
  reconcile) — semuanya dalaman pelayan, tiada permukaan API berubah.

**L26a — DITUTUP, tiada tindakan.** `../marc_go/TODO.md` meminta sahkan
Flutter tak melayan **429** pada `/auth/refresh` sebagai token tak sah
(kalau ya, had kadar bersama akan jadi forced-logout beramai-ramai).
Disahkan selamat: `api_client.dart` melayan **hanya 401** sebagai
`_RefreshOutcome.rejected`; 429 jatuh ke `networkFailure`, yang
mengekalkan refresh token. Backend juga sudah memberi `/refresh` dan
`/logout` baldi `auth-session` sendiri, berasingan daripada baldi `auth`
ketat.

## Jurang ujian

- [ ] Widget test `forgot_password_page.dart` — mesej kejayaan benar-benar
      **dirender**. Ujian sedia ada mengesahkan pemalar itu neutral (itu
      invarian keselamatan, dan sudah dikunci); yang tak dilindungi ialah
      `_sent` bertukar dan `Text(forgotPasswordSentMessage)` muncul. Kalau
      refactor memutuskan `setState`, ahli hantar emel, skrin tak berubah,
      mereka hantar lagi — dan setiap permintaan baharu **membunuh token
      sebelumnya** di backend, jadi pautan dalam emel yang mereka akhirnya
      buka sudah mati. Bug UI senyap yang jadi jauh lebih teruk kerana
      kelakuan backend. Tak disekat kerana `login_page`/`register_page`
      pun tiada widget test. (Semakan akhir L32, 2026-08-22.)
- [ ] Widget test `post_card.dart` (rendering + tindakan)
- [ ] Unit test `PostRepository.uploadImage` (mock respons presign)
- [ ] Pas UI visual menyeluruh pada peranti. Aliran donation, upload gambar,
      grid + pemapar dah disahkan pada Infinix X6833B; selebihnya belum.

## Resit — R2 dibuang, buka via `printing` (2026-08-24)

Sambungan perubahan backend (`marc_go/TODO.md` "Resit — R2 dibuang,
stream terus"): resit PDF tak lagi disimpan R2, backend stream bait
PDF terus. Client kena tukar cara terima + buka resit.

- `payment_providers.dart`: `ReceiptLinkResult` (URL) →
  `ReceiptBytesResult` (bait). `_fetch` guna `responseType: bytes`.
  Ralat 409 kekal mesej sedia (`receiptNotReadyMessage`); ralat LAIN
  guna helper baharu `_extractBytesError` — badan ralat backend sampai
  sebagai `List<int>` mentah (bukan Map ter-nyahsiri) sebab
  `responseType: bytes` dipaksa utk terima PDF, jadi nyahsiri JSON
  manual dahulu sebelum jatuh balik ke `extractErrorMessage`.
- `payment_history_page.dart`: buang `launchUrl` pada URL R2 luaran,
  guna pakej BAHARU `printing` (`Printing.layoutPdf`) — dialog
  preview/simpan/kongsi/cetak native terus drpd bait PDF, elak perlu
  `path_provider`+`open_filex`+`share_plus` berasingan cuma utk "buka
  satu PDF".
- **`printing` bawa kod native (Android/iOS)** — projek ni ada siling
  `compileSdk 35` ketat (lihat nota `mobile_scanner`/
  `permission_handler` di `pubspec.yaml`). DISAHKAN `flutter build apk
  --debug` lulus (APK prod+staging dihasilkan, tiada ralat AGP/
  compileSdk, tiada plugin KGP baharu) SEBELUM commit — sama disiplin
  yang dipakai utk `mobile_scanner` dulu.

`flutter analyze` bersih, 258/258 ujian lulus.

**Naming fail lebih baik, 2026-08-24** — nama fail resit dulu generik
(`resit-yuran-pendaftaran.pdf`, sama untuk SEMUA muat turun jenis tu,
tak boleh dibezakan kalau ahli simpan >1). Backend kini hantar nama
sebenar via header `Content-Disposition`
(`Resit-{Pendaftaran,Aktiviti,Sokongan}-MARC-{gateway_ref}.pdf` — padan
PERSIS konvensyen lampiran emel resit donation sedia ada). Flutter
`_parseContentDispositionFilename` (`payment_providers.dart`) hurai
header tu, `payment_history_page.dart` hantar terus ke
`Printing.layoutPdf(name: ...)` — fallback `'resit.pdf'` kalau header
tiada/tak dpt dihurai.

- [ ] **Belum disahkan pada peranti sebenar.** Dialog `Printing.
      layoutPdf` (preview/simpan/kongsi/cetak) untuk ketiga-tiga jenis
      resit (pendaftaran/aktiviti/donation) belum pernah dilihat mata.
- [ ] **Tiada widget test baharu** untuk `_downloadReceipt`/
      `Printing.layoutPdf` — jurang sedia ada (`PaymentHistoryPage`
      tiada widget test sebelum ni pun).

### Pertanyaan pengguna 2026-08-24 (rate limit/cache/local DB) — jawapan direkod

- **Rate limit**: dah wujud, tak tersentuh oleh perubahan R2 di atas
  (`payment-receipt`, 6s/5 setiap IP, ketiga-tiga endpoint resit —
  `marc_go/internal/http/router.go`).
- **Cache backend**: TAK disyorkan. Jana PDF murah (CPU sahaja, tiada
  panggilan luar, <10ms), traffic resit rendah — cache backend tambah
  kerumitan tanpa faedah ketara pada skala kelab ni.
- [ ] **Local DB/cache di Flutter untuk resit — BELUM dibina, idea
      disahkan berbaloi.** Resit IMMUTABLE lepas `succeeded`/`paid`
      (kandungan tak pernah berubah lepas dijana) — selamat cache
      SELAMA-LAMANYA tanpa isu "basi". Cadangan: simpan BAIT PDF terus
      (bukan re-derive metadata) dlm storan lokal (`path_provider`),
      keyed ikut payment ID. Kali kedua ahli nak resit sama → terus
      dari cakera, tiada round-trip network — jimat bandwidth/edge
      cost, app rasa laju. Keputusan pakej (`sqflite`/`Hive`/fail
      terus via `path_provider`) belum dibuat — perlu brainstorm
      berasingan bila nak proceed.
- [x] **Tak perlu hash/signature untuk cache ni — rasional direkod.**
      Resit BUKAN token pengesahan yang disemak sistem/pihak LAIN
      (bandingkan `activity_certificates` yang ADA endpoint pengesahan
      awam org lain scan QR — situasi tu MEMANG perlukan integrity
      check sisi server). Resit cuma dokumen maklumat rekod ahli
      sendiri. Kalau ahli "hack" cache lokal telefon dia sendiri utk
      papar jumlah palsu: (1) cuma DIA sendiri tertipu — tiada orang
      lain nampak, (2) rekod SEBENAR (`registration_payments`/
      `payment_logs` Postgres) langsung tak terjejas — itu tetap
      sumber kebenaran tunggal, (3) tiada laluan "upload semula" resit
      yang di-cache balik ke server — app ni read-only untuk resit.
      Access control sebenar (`user_id = caller` pada query DB) dah
      cukup; lepas ahli fetch resit DIA SENDIRI sekali, apa dia buat
      dgn salinan tu di device dia sendiri bukan risiko keselamatan
      MARC.

### Pertanyaan pengguna 2026-08-24 — emel resit yuran ✅ DIBINA (backend sahaja)

- [x] **Yuran pendaftaran/aktiviti (ToyyibPay) kini hantar emel resit
      — DIBINA 2026-08-24, sepenuhnya sisi `marc_go`.** Package baharu
      `internal/receiptmail` (`FeeReceipt` struct + `Send`, loosely
      coupled — dipanggil dua webhook, `registration_payment.go`/
      `activity_registration_payment.go`, tanpa mereka import satu
      sama lain). Butiran penuh: `marc_go/TODO.md` bahagian "Yuran
      pendaftaran/aktiviti kini hantar emel resit".
      **Tiada kerja Flutter** — ni sepenuhnya backend (webhook →
      Resend terus), tak sentuh app langsung. Ahli akan mula terima
      emel resit automatik sebaik bayaran disahkan, sama macam
      donation sedia ada.
      - [ ] Belum dihantar/dilihat pada inbox sebenar (Gmail/Outlook)
            — disahkan setakat payload dijana betul secara lokal.

## Terma & Syarat / Dasar Privasi dalam-app (2026-08-16)

Dua butang baharu di `about_page.dart` ("Terma & Syarat" / "Dasar Privasi")
buka halaman berkenaan dalam-app guna `webview_flutter` (bukan
`launchUrl` external — tak macam pautan `hafizbahtiar.com` sedia ada, yang
sengaja kekal luar app). Route generik `/legal/:doc` (`router.dart`) petakan
slug ke tajuk + `https://marc.hafizbahtiar.com/<doc>` (sumber:
`marc_astro/src/pages/terma-dan-syarat.astro` dan `dasar-privasi.astro`).
Widget kongsi: `shared/widgets/web_view_page.dart`.

`webview_flutter` dipilih berbanding `flutter_inappwebview` — pakej rasmi
Flutter, kurang berisiko terhadap siling **compileSdk 35** projek ni (lihat
nota `permission_handler`/`mobile_scanner` di atas). Disahkan:
`flutter build apk --debug` lulus (74.3s, cuma amaran KGP sedia ada), 233/233
ujian lulus, `flutter analyze` bersih.

- [ ] **Tak pernah dilihat pada peranti sebenar.** Susun atur `WebViewPage`
      (progress bar, appbar), rendering sebenar halaman Astro dalam
      `WebViewWidget`, dan navigasi balik/tutup — semua andaian belum
      disahkan mata.

## Notifikasi — polish visual (2026-08-16)

`notifications_page.dart` disusun semula: kumpulan tarikh ("Hari ini" /
"Semalam" / "Lebih awal", gaya disalin daripada `_SectionHeader` di
`payment_history_page.dart`), baris tak dibaca kini ditanda dengan tint latar
(`surfaceContainerHighest`) + teks tebal (titik trailing lama dibuang —
lebihan isyarat), `ListView.separated`+`Divider` ditukar ke `ListView.builder`
tanpa garisan (padding + tint sudah cukup pisah baris), padding kandungan
`ListTile` diselaraskan (`horizontal: 20`, padan `payment_history_page.dart`),
dan butang "Tanda semua dibaca" kini `disabled` bila tiada notifikasi belum
dibaca. Tiada perubahan pada data/provider/routing — semata polish visual.
Disahkan: `flutter analyze` bersih, 233/233 ujian lulus.

- [ ] **Tak pernah dilihat pada peranti sebenar.** Susun atur kumpulan
      tarikh, tint baris tak dibaca, dan padding baharu — semua andaian
      belum disahkan mata (skrin lama pun belum pernah, ikut nota "Pas UI
      visual menyeluruh" di bawah).

## Like button — betulkan tint + tambah bounce (2026-08-16)

`_ActionButton` (`post_card.dart`) dah lama ada komen dakwa "tint separa-lut
bila active", tapi `BoxDecoration` bulatan sentuh tak pernah diberi `color:`
— tint itu tak pernah render. Dibetulkan: `color: active ? color.withValues
(alpha: 0.12) : null`. Ditambah juga "pop" gaya Threads/Twitter: ikon like
melantun skala 1.0 → 1.35 → 1.0 (`AnimationController` + `TweenSequence`)
bila `likedByMe` bertukar false → true — bukan pada setiap rebuild, hanya
peralihan. Param `bounceOnActive` khusus untuk butang like; butang comment
kekal tanpa animasi. `_ActionButton` bertukar `StatelessWidget` →
`StatefulWidget` untuk `AnimationController`. Disahkan: `flutter analyze`
bersih, 233/233 ujian lulus.

- [ ] **Tak pernah dilihat pada peranti sebenar.** Tint active + animasi
      bounce — belum disahkan mata (`post_card.dart` sendiri belum pernah
      di-screenshot ikut nota "Pas UI visual menyeluruh" di bawah).

**Ralat susulan dibaiki**: `PostCard` dalam `feed_page.dart` (`ListView.
builder`) tiada `key:` — bila `removePost` mengecut senarai (atau
refresh/load-more ubah susunan), Flutter guna semula Element/State
mengikut INDEKS, bukan identiti post. `_ActionButtonState` yang baru
bawa `AnimationController` jadi terdedah: State animasi post lama boleh
terlekat pada post lain semasa deactivate, tercetus `FlutterError`
"Looking up a deactivated widget's ancestor is unsafe". Dibaiki:
`key: ValueKey(post.id)` pada `PostCard` dalam `feed_page.dart`.
(`post_detail_page.dart` guna SATU `PostCard` sahaja — bukan senarai
berubah — jadi tak terjejas.)

## PUNCA SEBENAR: `late final` AnimationController baca kali pertama dalam dispose() (2026-08-16)

Stack trace penuh (selepas log ditambah) dedah punca SEBENAR ralat
`FlutterError: Looking up a deactivated widget's ancestor is unsafe` —
BUKAN isu context notifikasi/router (fix itu di bawah kekal betul sebagai
amalan baik, tapi bukan punca):

```
#8  _ActionButtonState._controller (post_card.dart:203:28)
#10 _ActionButtonState.dispose (post_card.dart:248:10)
```

`_ActionButton` (`post_card.dart`) guna `late final _controller =
AnimationController(vsync: this,...)` — malas, cuma cipta bila `_controller`
DIBACA kali pertama. Butang **comment** (`bounceOnActive: false`) tak
pernah sentuh `_controller`/`_scale` dalam `build()` (cabang `: icon`
terus). Jadi bacaan PERTAMA field tu jatuh dalam `dispose()` sendiri —
`_controller.dispose()` cipta `AnimationController` BAHARU (`vsync: this`)
semasa widget tengah di-unmount, carian ancestor `TickerMode` di dalamnya
gagal sebab context dah tak aktif. Ralat tercetus setiap kali ANY
`_ActionButton` (bukan sahaja like) di-dispose — padam post, navigasi
keluar skrin feed/detail, senarai rebuild, dsb. Notifikasi cuma laluan
biasa pengguna navigate keluar/masuk skrin post, bukan punca istimewa.

Dibaiki: `_controller`/`_scale` jadi nullable, dicipta EAGER dalam
`initState()` (semasa mesti masih mounted) HANYA untuk butang yang
`bounceOnActive: true` (like). Butang comment terus tak pernah cipta
controller — `dispose()` guna `_controller?.dispose()`. Log diagnostik
sementara (debugPrint) yang ditambah untuk kenal pasti isu ni dah dibuang
balik selepas punca disahkan; hook ralat global (`FlutterError.onError` +
`PlatformDispatcher.instance.onError`) dalam `main.dart` DIKEKALKAN —
manfaat am, bukan spesifik isu ni.

Disahkan: `flutter analyze` bersih, 233/233 ujian lulus.

- [ ] **Belum disahkan pengguna pada peranti sebenar** — perlu ulang
      senario yang sama (padam post / navigasi keluar dari skrin
      post/notifikasi) untuk sahkan ralat dah hilang sepenuhnya.

## Notifikasi — navigasi guna router terus, bukan context (2026-08-16)

Ketukan baris notifikasi (`onTap` dlm `_NotificationsPageState`) buat
`await markRead(...)` dahulu, kemudian `context.push(destination)` guna
`BuildContext` baris `ListTile` tu sendiri — kalau senarai rebuild semasa
`await` (status dibaca berubah), context baris tu boleh jadi lapuk sebelum
push sempat jalan. **Ini bukan punca ralat yang dilaporkan** (lihat entri
di atas), tapi kekal sebagai fix — amalan yang lebih selamat, padanan
corak yang `push_service.dart` DAH guna untuk ketukan notifikasi OS.

## Polish yang diketahui

- [ ] Kawalan pemapar gambar tak pudar semasa leret-untuk-tutup.
      `ExtendedImageSlidePage` cuma dedah offset leret kepada handler
      latarnya, bukan kepada child sembarangan — jadi ia perlukan state
      dialirkan pada setiap frame gerak isyarat. Bukan percuma.
