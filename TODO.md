# MARC Flutter — TODO

Backend TODO penuh (schema, endpoint, keputusan produk) ada di
`/Users/hafiz/Developments/marc_go/TODO.md` — fail ni fokus kerja app
Flutter sahaja.

## Selesai

- **Supabase → Go backend integration penuh** (Dio, secure storage token,
  refresh interceptor, semua provider guna REST API). Independent review
  (Opus) + audit susulan jumpa & fix 9 isu (session handling, device token
  unlink waktu logout, UX error state, dsb) — lihat git log untuk detail.

---

## Stage 10 (Flutter) — Posts feature UI

Design & keputusan produk penuh ada di `marc_go/TODO.md` Stage 10 — rujuk
situ untuk data model + API contract. Fail ni cuma checklist kerja UI.

### Struktur baru

```
lib/features/posts/
  post_providers.dart       -- Post/Comment model (fromJson), postsProvider
                              (paginated FutureProvider / infinite scroll),
                              PostRepository (create/edit/delete/like)
  feed_page.dart             -- infinite scroll list, pull-to-refresh
  post_detail_page.dart      -- satu post + nested comment thread (depth 2)
  create_post_page.dart      -- compose: text + pilih gambar (image_picker)
  widgets/
    post_card.dart           -- ringkasan post untuk feed (content, imej,
                              like count, comment count, "(disunting)")
    comment_tile.dart        -- recursive sampai depth 2, reply inline
    image_carousel.dart      -- papar 1+ gambar dalam post
```

### Kerja

- [ ] Package baru: `image_picker` (pilih gambar dari galeri/kamera)
- [ ] `PostRepository` — upload flow: `POST /uploads/presign` → upload
  terus ke R2 guna URL tu (`http.put` biasa, bukan Dio — presigned URL
  bukan endpoint backend kita) → `POST /posts` dengan `r2_keys[]`
- [ ] `postsProvider` — infinite scroll (cursor-based), gate
  `email_verified` di UI jugak (papar mesej "sahkan email dulu" kalau
  belum, bukan panggil API yang akan 403)
- [ ] `feed_page.dart` — list post, like button (optimistic update — toggle
  UI serta-merta, revert kalau API gagal), tap → `post_detail_page.dart`
- [ ] `post_detail_page.dart` — comment thread nested (indent depth 2),
  reply inline, like comment
- [ ] `create_post_page.dart` — form: text + attach gambar (multi), submit.
  Kalau role management → toggle "Jadikan Pengumuman" (`type: announcement`)
- [ ] Edit/delete UI — owner nampak butang edit/delete pada post/comment
  sendiri; **management nampak butang delete pada SEMUA post/comment**
  (moderation)
- [ ] `notifications_page.dart` — REWRITE penuh (sekarang placeholder
  kosong): `GET /notifications`, tap notification → navigate ke post/comment
  berkaitan, tanda dibaca
- [ ] Router (`app/router.dart`) — route baru: `/posts`, `/posts/:id`,
  `/posts/new`
- [ ] **Keputusan UI belum dibuat** (kena putus sebelum/semasa implement):
  tab feed ni letak kat mana dalam `nav_shell.dart`? Ganti tab Home sedia
  ada, atau tab baru? (Home sekarang papar member card + welcome — mungkin
  Feed jadi tab utama baru, Home jadi kurang penting / digabung)

### Test

- [ ] Widget test: `post_card.dart` papar content/like count betul
- [ ] Widget test: `comment_tile.dart` nested rendering depth 2 (reply
  kat reply-paras-2 papar sebagai top-level reply baru, bukan indent lagi)
- [ ] Unit test: `PostRepository` upload flow (mock presign response)
