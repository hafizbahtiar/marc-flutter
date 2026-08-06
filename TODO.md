# MARC Flutter — TODO

Backend TODO penuh (schema, endpoint, keputusan produk) ada di
`/Users/hafiz/Developments/marc_go/TODO.md` — fail ni fokus kerja app
Flutter sahaja.

## Selesai

- **Supabase → Go backend integration penuh** (Dio, secure storage token,
  refresh interceptor, semua provider guna REST API). Independent review
  (Opus) + audit susulan jumpa & fix 9 isu (session handling, device token
  unlink waktu logout, UX error state, dsb).

- **Stage 10 — Posts feature UI** ✅ (done, kecuali R2 upload — lihat "Belum")
  Nav restructure (keputusan user): 2 tab bawah (Feed, Profil) — Feed jadi
  home screen app (Twitter/FB-style), Ahli + Notifikasi jadi icon button
  kat AppBar Feed (bukan tab berasingan). `home_page.dart` dibuang, gantikan
  `feed_page.dart`.

  Struktur baru:
  ```
  lib/features/posts/
    post_models.dart           -- Post/Comment/Author/AppNotification
    post_providers.dart        -- FeedNotifier (paginated, optimistic like),
                                PostRepository (create/edit/delete/like/upload)
    feed_page.dart              -- infinite scroll, AppBar Ahli+Notifikasi icon, FAB
    post_detail_page.dart       -- post + nested comment thread (depth 2) + reply box
    create_post_page.dart       -- text + multi-image + toggle Pengumuman (management)
    widgets/
      post_card.dart, comment_tile.dart, image_carousel.dart
  lib/features/notifications/
    notifications_providers.dart, notifications_page.dart (REWRITE penuh)
  lib/shared/relative_time.dart
  ```

  **Verified** (bukan cuma `flutter analyze`):
  - `flutter analyze` 0 isu, 17 test lulus, `flutter build web --debug` compile bersih
  - **Contract test lawan Go backend sebenar** (local, bukan mock): feed →
    post detail → comments deserialize field-for-field betul; nested reply
    (depth 3 attempt) — client confirm `parent_comment_id` betul-betul
    flatten ke comment depth-1 (padan dgn backend); like count + liked_by_me
    tepat; notifications shape parse betul
  - **Upload R2 sebenar diuji** — jumpa & fix bug backend (`aws-sdk-go-v2`
    auto-checksum pecahkan signature presigned URL, lihat `marc_go` commit
    `7c2fe81`). Lepas fix tu, presign URL jana betul tapi **PUT sebenar
    masih 403 AccessDenied** — nampak macam isu permission scope R2 API
    token (bukan code), lihat "Belum" di bawah

## Belum

- [ ] **R2 API token permission** — perlu semak Cloudflare dashboard: token
  ada "Object Read & Write" untuk bucket `marc-staging`? Account ID/bucket
  name betul-betul padan dengan yang di `.env`? Upload gambar backend dah
  betul code-wise (verified presign + checksum fix), tapi PUT sebenar ke R2
  masih 403 — bukan sesuatu yang boleh saya diagnose lagi tanpa akses dashboard
- [ ] Isi `R2_PUBLIC_URL` dalam `.env` (marc_go) — kosong sekarang, jadi
  gambar yang berjaya upload pun takkan ada URL untuk dipaparkan balik
- [ ] Widget test: `post_card.dart`, `comment_tile.dart` nested rendering
- [ ] Unit test: `PostRepository.uploadImage` (mock presign response)
- [ ] Test app betul-betul di simulator/device (setakat ni verified guna
  `flutter build web` + contract test API sahaja, belum run visual UI
  sebenar)
