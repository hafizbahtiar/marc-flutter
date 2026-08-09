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
- [ ] **Hadkan dimensi semasa upload** (`image_picker` `maxWidth`/
      `maxHeight`). Sekarang kita simpan asal sehingga 4608px yang tak
      pernah dipapar pada saiz itu — jimat storan R2 + kuota r2.dev. Ia
      menurunkan kualiti secara kekal untuk upload baharu, jadi keputusan
      kau.
- [ ] **Kisah pembangun pada halaman sokongan** (`_DeveloperStory` dalam
      `donation_page.dart`) ditulis daripada satu fakta yang kau beri. Baca
      dan tulis semula dalam suara kau sendiri. Warden tak dinamakan —
      itu identiti orang lain, perlu kebenaran mereka.

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
