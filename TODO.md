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
- [ ] **Kisah pembangun pada halaman sokongan** (`_DeveloperStory` dalam
      `donation_page.dart`) ditulis daripada satu fakta yang kau beri. Baca
      dan tulis semula dalam suara kau sendiri. Warden tak dinamakan —
      itu identiti orang lain, perlu kebenaran mereka.

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
