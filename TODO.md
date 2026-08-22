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

- [ ] **ToyyibPay: yuran pendaftaran ahli (sekali bayar) + yuran
      aktiviti berbayar** — **BUKAN** "yuran ahli berulang"/dues (framing
      lama dibetulkan 2026-08-15, sesi 3). Gateway kod **siap +
      disahkan sandbox sebenar** (`marc_go/internal/payment/
      toyyibpay.go`), lihat `PAYMENT-TOYYIB.md` untuk status penuh —
      belum diwiring ke handler/route Flutter atau backend.

      Isu reka bentuk paling penting: **ToyyibPay tiada sah callback
      kriptografi** yang boleh dipercayai (dua sumber sekunder bagi
      formula `hash` bercanggah) — backend poll `getBillTransactions`
      untuk sahkan status, bukan percaya body callback terus (butiran
      penuh dalam `PAYMENT-TOYYIB.md` dan `../marc_go/TODO.md`).

      Bila sisi backend siap, perlu skrin baharu di sini: (1) langkah
      bayar dalam aliran daftar ahli baharu (lokasi tepat — sebelum atau
      selepas giliran kelulusan management — masih keputusan produk
      terbuka), (2) langkah bayar pada pendaftaran aktiviti berbayar
      (`activity_detail_page.dart`, ikut pattern skrin dues-status/gate
      sedia ada macam `_EmailNotVerifiedView`/`_PendingStatusView` dalam
      `feed_page.dart`).

      `RedirectCheckoutHandler` dah sedia untuk gateway hosted-redirect
      (disahkan https-only selepas audit 2026-08-15) — tak perlu ubah
      bila endpoint backend sedia.

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

## Backend L32 (2026-08-22) — reset kata laluan ✅

Skrin `forgot_password_page.dart` baharu + pautan "Lupa kata laluan?" pada
`login_page.dart`. Flutter hanya mengumpul EMEL; kata laluan baharu ditaip
pada halaman `marc_astro` (tiada app-link https dikonfigur, jadi pautan
emel membuka pelayar).

⚠️ `forgotPasswordSentMessage` MESTI kekal neutral — backend pulang 204
sama ada akaun wujud atau tidak, dan mesej yang berkata "Pautan dihantar!"
akan membocorkan apa yang backend sengaja sembunyikan. Dikunci oleh ujian.

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
