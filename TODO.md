# MARC Flutter — TODO

Kerja yang **belum siap** sahaja. Sejarah penuh ada dalam git log.
Corak wajib + gotcha platform: [`README.md`](./README.md).
Aliran donation: [`PAYMENT-STRIPE.md`](./PAYMENT-STRIPE.md).
Backend: `../marc_go/TODO.md`.

---

## Ciri belum start

- [ ] **Yuran ahli (ToyyibPay) + SociaBuzz (<RM500)** — backend pun belum.
      Bila ToyyibPay siap, perlu skrin dues-status/gate baharu (ikut pattern
      `_EmailNotVerifiedView` / `_PendingStatusView` dalam `feed_page.dart`).
      `RedirectCheckoutHandler` dah sedia untuk gateway hosted-redirect.

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

## Jurang ujian

- [ ] Widget test `post_card.dart` (rendering + tindakan)
- [ ] Unit test `PostRepository.uploadImage` (mock respons presign)
- [ ] Pas UI visual menyeluruh pada peranti. Aliran donation, upload gambar,
      grid + pemapar dah disahkan pada Infinix X6833B; selebihnya belum.

## Polish yang diketahui

- [ ] Kawalan pemapar gambar tak pudar semasa leret-untuk-tutup.
      `ExtendedImageSlidePage` cuma dedah offset leret kepada handler
      latarnya, bukan kepada child sembarangan — jadi ia perlukan state
      dialirkan pada setiap frame gerak isyarat. Bukan percuma.
