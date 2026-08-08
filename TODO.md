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

- **Had saiz & bilangan gambar** ✅ (done) — `create_post_page.dart`:
  `_pickImages` cap slot baki (max 4 total imej setiap post; kalau baki 1
  slot, guna `pickImage()` tunggal sebab `pickMultiImage(limit: 1)`
  throws), pre-check saiz fail (5MB) lepas pick, tolak gambar lebih besar
  dengan snackbar mesra tanpa attempt upload. Butang "Tambah gambar" papar
  kaunter `(n/4)` dan disable bila dah cukup 4. **Ni UX sahaja** — security
  boundary sebenar ada di backend (`VerifyImageSize` via `HeadObject` +
  had `r2_keys` array di `posts.go`), client-side check ni boleh
  di-bypass kalau panggil API terus, tapi backend tetap tolak.

- **Stage 11 — Member approval status UI** ✅ (done)
  Design penuh di `docs/superpowers/specs/2026-08-07-member-approval-status-ui-design.md`.
  Feed content-gated (bukan router-level) bila `profile.status != 'approved'`
  — skrin "menunggu kelulusan"/"ditolak" dengan butang semak semula.
  `PendingMembersPage` baru (management-only, icon button kat AppBar
  Ahli) untuk approve/reject. `AppNotification.postId` kini nullable +
  3 jenis notification baru (`member_pending`/`member_approved`/
  `member_rejected`) dirender dengan icon/copy sendiri, tap-guard elak
  navigate ke post yang tak wujud.

- **Security/correctness audit (Opus, 2026-08-07)** ✅ (done, all fixed)
  Independent audit atas seluruh `lib/` (bukan diff-scoped). Ringkasan:
  tiada Critical, `flutter analyze` bersih sepanjang, satu je force-unwrap
  (`!`) dalam seluruh app dan provably safe, JSON parsing padan
  nullability backend hampir field-for-field.

  **High (1/1 fixed, commit `4b18cfe`):** cached feed/notifications/
  postDetail/comments provider kekal terpapar lepas logout (bukan
  `autoDispose`, tak watch auth state) — user seterusnya pada peranti
  sama boleh nampak data user sebelum dia. Fix: `.select(isLoggedIn)`
  guard di semua 4 provider (padanan pattern `membersProvider` sedia ada).

  **Medium (8/8 fixed, commits `e461bed`, `f751228`, `794e5b5`,
  `68fc42e`, `3b4b3b0`, `bae98ef`):**
  - Optimistic like-revert (`FeedNotifier.toggleLike`) snapshot SEMUA
    state lama bila gagal, bukan cuma 1 post — boleh hapus post yang
    baru loadMore. Fix: revert cuma post berkenaan, atas state TERKINI.
  - `loadMore()` race dengan `refresh()` — hasil loadMore lambat boleh
    overwrite refresh yang dah siap. Fix: generation counter guard.
  - Feed gate cuma check `status`, bukan `email_verified` — approved-
    tapi-belum-verify user stuck kat skrin ralat generic yang tak boleh
    pulih. Fix: `_EmailNotVerifiedView` baru (resend + semak semula).
  - "Semak semula" punya refresh tiada try/catch — unhandled exception,
    tiada feedback. Fix: try/catch + snackbar (verified `copyWithPrevious`
    Riverpod dah handle fail-open concern, tak perlu extra state).
  - `signOut()` block sampai 12s (await unlink SEBELUM clear, walaupun
    comment cakap sepatutnya serta-merta) — tiada busy state, boleh
    double-tap. Fix: tangkap token dulu, clear() serta-merta, unlink +
    logout server jalan unawaited lepas tu guna token yang ditangkap.
  - 4 aksara (like comment, padam comment, mark-read, mark-all-read)
    fire-and-forget tanpa error handling/feedback. Fix: try/catch +
    snackbar konsisten, `markRead` tambah invalidation yang hilang.
  - Like/comment dari detail page tak sync balik ke feed card. Fix:
    `FeedNotifier.patchPost` + `_syncPostToFeed` helper lepas setiap
    mutation (like/edit/comment/delete comment).
  - Mesej ralat backend yang spesifik (cth: "cuma management boleh buat
    pengumuman") dibuang, ganti generic "Gagal...Cuba lagi." di mana-mana
    selain auth. Fix: `extractErrorMessage` dipindah ke `core/error_utils.dart`,
    dipakai di 8 lokasi.

  **Low (11/11 fixed, commits `fd5deb0`, `ce54003`, `cf28f8f`, `4743c70`,
  `8feecbe`, `4a38f44`):** r2_key ownership (dah selesai side-effect
  backend H2); auth-refresh race (`_lastRefreshRejected` shared state →
  `_RefreshOutcome` enum returned terus); "Edit" menu post/comment yang
  dulu dead sekarang wired penuh (dialog-based); relative-time UTC bug;
  status fail-open default (`'approved'`→`'pending'`); tiada handler tap
  push notification (navigate ke `/notifications` — deep-link terus ke
  post perlukan backend hantar `additionalData`, dicatat sebagai
  follow-up, bukan skop sekarang); status field default fail-open;
  notification pagination tak implement (kini infinite-scroll, padanan
  pattern `FeedNotifier`); pull-to-refresh flash skrin kosong; upload
  content-type dari extension bukan byte sebenar (kini sniff magic
  bytes); gambar diupload orphan bila post gagal separuh jalan (kini
  retry-safe, tak re-upload gambar yang dah berjaya); approve/reject
  tiada double-tap guard; `_ImageThumb` re-read file dari disk setiap
  rebuild.

## Belum

- [ ] **Donation page (Stripe, Payment Element)** — backend dah siap
  (`marc_go/TODO.md` Stage 12), refactor 2026-08-09 guna interface
  `payment.Gateway`: `POST /donations/checkout` (awam, boleh guest —
  hantar `donor_email` wajib kalau tak log masuk, optional kalau log
  masuk sebab dikaitkan `user_id` auto) pulang
  `{gateway, client_secret, redirect_url}` — **bukan `client_secret`
  je lagi**. Buat masa ni `gateway` selalu `"stripe"` +
  `redirect_url` selalu kosong (SociaBuzz/ToyyibPay belum wired), tapi
  client kena baca field `gateway` untuk tentukan flow, JANGAN andaikan
  Stripe terus — bila SociaBuzz siap, response boleh jadi
  `redirect_url` diisi sebaliknya. **Belum start di Flutter.** Kerja:
  - [ ] Tambah `flutter_stripe` dependency, init `Stripe.publishableKey`
    di `main.dart` (perlu `STRIPE_PUBLISHABLE_KEY` — boleh hardcode/env,
    bukan secret, selamat di client)
  - [ ] **Cerminkan Strategy pattern backend di Dart** (keputusan user
    2026-08-09, "frontend dan backend guna interface"): abstract class
    `DonationCheckoutHandler` (method `handle(DonationCheckoutResponse)
    -> Future<DonationResult>`), implementation `StripeCheckoutHandler`
    (guna `flutter_stripe` confirmPayment bila `client_secret` terisi)
    + `RedirectCheckoutHandler` (guna `url_launcher` bila `redirect_url`
    terisi — untuk ToyyibPay/SociaBuzz kemudian). `donation_page.dart`
    cuma panggil `/donations/checkout`, lookup handler ikut
    `response.gateway`, delegate — tak perlu tahu logik Stripe/ToyyibPay
    spesifik.
  - [ ] `donation_page.dart` baru: form amount + nama/emel (emel wajib
    kalau user tak log masuk — cocokkan validation server), call
    `/donations/checkout`, papar `CardFormField` (bukan `PaymentSheet`
    — keputusan elak setup Apple Pay/Google Pay buat masa ni), confirm
    guna `Stripe.instance.confirmPayment(clientSecret)`, skrin result
  - [ ] Route `/donate` + letak entry point (Profile page buat masa ni;
    lokasi "betul" — tab ke landing luar — belum putus, lihat TODO
    backend)
  - [ ] Test dengan Stripe test card (`4242 4242 4242 4242`) lepas
    `STRIPE_SECRET_KEY` diisi backend `.env`
- [ ] **Yuran ahli (ToyyibPay) + SociaBuzz (<RM500)** — belum start
  langsung, backend pun belum (lihat "belum putus" di `marc_go/TODO.md`
  Stage 12). Bila ToyyibPay siap: perlu skrin dues-status/gate baharu
  (pattern sama macam `_EmailNotVerifiedView`/`_PendingStatusView` di
  `feed_page.dart`).
- [ ] **R2 API token permission** — perlu semak Cloudflare dashboard: token
  ada "Object Read & Write" untuk bucket `marc-staging`? Account ID/bucket
  name betul-betul padan dengan yang di `.env`? Upload gambar backend dah
  betul code-wise (verified presign + checksum fix), tapi PUT sebenar ke R2
  masih 403 — bukan sesuatu yang boleh saya diagnose lagi tanpa akses
  dashboard. Confirm semula semasa kerja had saiz gambar — 403 sama
  berlaku, bukan regresi baru
- [ ] Isi `R2_PUBLIC_URL` dalam `.env` (marc_go) — kosong sekarang, jadi
  gambar yang berjaya upload pun takkan ada URL untuk dipaparkan balik
- [ ] Widget test: `post_card.dart`, `comment_tile.dart` nested rendering
- [ ] Unit test: `PostRepository.uploadImage` (mock presign response)
- [ ] Test app betul-betul di simulator/device (setakat ni verified guna
  `flutter build web` + contract test API sahaja, belum run visual UI
  sebenar)
