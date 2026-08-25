# Local Drafts for Post/Comment Composers

Date: 2026-08-25
Status: approved for implementation

## Problem

`create_post_page.dart` (new post) and the comment/reply composer inside
`post_detail_page.dart` hold their typed content purely in a
`TextEditingController` / local `State`. Navigating away, backgrounding the
app, or a crash loses whatever was typed - there is no draft concept
anywhere in the app today. `shared_preferences` is the only local
persistence dependency currently used (single key, theme mode) and isn't a
good fit for structured, possibly-concurrent draft rows (a user can have
one in-progress new post AND one or more in-progress replies to different
comments at once).

This spec covers: a local SQL-backed drafts store, a shared
back-navigation-intercept pattern (Twitter-style "Simpan draf / Buang /
Batal"), and wiring it into both composers. No drafts-list/management UI -
one overwritable slot per composer context.

## Storage: sqflite

Chosen over extending `shared_preferences` with a JSON blob: the data is
flat rows keyed by a slot string, with simple upsert/delete-by-key access -
exactly what `sqflite` gives directly via SQL, without `drift`'s codegen
overhead for a single-table need. `shared_preferences` was rejected because
a key-value string store is the wrong shape once multiple concurrent draft
rows exist (replying-to-comment-A and replying-to-comment-B drafts both
alive at once).

Add `sqflite: ^2.x` to `pubspec.yaml`.

## Schema

One table, opened via a new `lib/core/local_db.dart` (mirrors the role
`dioProvider`/`db.go` play for the network/Postgres side - a single place
that owns the `Database` instance):

```sql
create table drafts (
  key text primary key,       -- see "Draft key scheme" below
  kind text not null,         -- 'post' | 'comment'
  content text not null,
  is_announcement integer,    -- post-only; null for comment drafts
  updated_at text not null    -- ISO8601, informational only (no TTL/cleanup in v1)
);
```

No migrations system needed yet - `onCreate` only, matching the single-table
scope. If a second table is ever needed, add a real `onUpgrade` path then.

## Draft key scheme

- New post composer: fixed key `'new_post'` (one slot - the composer is a
  single full-screen route, only one can be open at a time).
- Comment/reply composer: `'reply:{postId}:{parentCommentId ?? "root"}'` -
  keyed by which comment (if any) is being replied to, so switching which
  comment you're replying to within the same `PostDetailPage` visit doesn't
  clobber a different in-progress reply. `postId` is included so drafts
  from different posts never collide.

## Repository

`lib/shared/local_drafts_repository.dart` - shared rather than
post-feature-scoped, since both the post and comment composers use it and
it has no post-feature-specific logic:

```dart
class DraftRepository {
  Future<Draft?> get(String key);
  Future<void> save(String key, {required String kind, required String content, bool? isAnnouncement});
  Future<void> delete(String key);
}
```

Exposed as a Riverpod provider (`draftRepositoryProvider`), matching the
existing `postRepositoryProvider`/`profileRepositoryProvider` pattern.

## Interaction pattern (shared by both composers)

Explicitly **not** autosave-while-typing (confirmed with user - Twitter's
actual behavior is exit-time, not debounced). Nothing touches disk until
the user tries to leave with unsaved content:

1. Composer's `Scaffold` wrapped in `PopScope`. `canPop: false` whenever
   there is unsaved content (post: `_contentController.text.trim().isNotEmpty
   || _images.isNotEmpty`; comment: `_commentController.text.trim().isNotEmpty`).
   `PopScope` catches both the AppBar back arrow and the Android system
   back gesture/button (both route through `Navigator.maybePop`).
2. `onPopInvokedWithPop` (didPop == false) opens a 3-action dialog built on
   the existing `AppDialogShell`/`AppDialogAction` machinery (already
   renders N evenly-spaced buttons in a row - no new dialog primitive
   needed):
   - **Simpan draf** - upsert the row via `DraftRepository.save`, then pop.
     If images are currently picked (post composer only - see "Images"
     below), the button label becomes **"Simpan draf (gambar tidak
     disimpan)"** so the image loss is never a silent surprise.
   - **Buang** - `DraftRepository.delete(key)` (in case an older draft for
     this key existed), then pop without saving.
   - **Batal** - dialog closes, composer stays open, nothing changes.
3. On composer `initState`, `DraftRepository.get(key)` and, if a row
   exists, pre-fill the controller (and `_isAnnouncement` for posts)
   silently - no restore-prompt dialog (confirmed: auto-fill, matches
   "auto-isi terus").
4. On successful submit (`_submit`/`_sendComment` completing without
   error), `DraftRepository.delete(key)` - a sent post/comment is not a
   draft anymore, and a stale row would otherwise resurface next time that
   key is reused (e.g. replying to the same comment again later).

## Post composer changes (`create_post_page.dart`)

- Wrap `Scaffold` in `PopScope` per above.
- `initState`: load `'new_post'` draft, pre-fill `_contentController` and
  `_isAnnouncement` if present.
- `_submit` success path: delete `'new_post'` draft (in addition to the
  existing `context.pop()`).
- Images are never restored (see "Images" below) - a resumed draft always
  starts with `_images` empty even if the original session had picked
  photos.

## Comment composer changes (`post_detail_page.dart`)

- The composer is inline (bottom bar), not its own route, but the
  *page itself* is a route - so the same `PopScope` goes on
  `PostDetailPage`'s `Scaffold`, guarding on `_commentController.text.trim().isNotEmpty`
  regardless of `_replyingTo` (both a fresh top-level comment and a reply
  count as unsaved content).
- Draft key depends on `_replyingTo`: `'reply:${widget.postId}:${_replyingTo?.id ?? "root"}'`.
- Switching `_replyingTo` (tapping "Balas" on a different comment) while
  text is already typed does **not** auto-save the in-progress text under
  the old key - v1 keeps this simple - the text visually stays in the
  field (unchanged UX from today) and will save/restore keyed to whichever
  comment is selected *at the moment the user leaves the page*. Revisit
  only if this proves confusing in practice.
- On successful `_sendComment`, delete the draft for the key that was
  active at send time.

## Images - explicitly out of scope for v1

Twitter persists attached media in drafts by copying picked bytes into its
own permanent storage (not just the `image_picker` temp path, which iOS in
particular can evict independently of the app). That's meaningfully more
work (byte copy to app documents dir, orphan cleanup on discard/submit,
storage growth) for a feature that's easy to re-do (re-picking photos takes
seconds). v1 ships text-only drafts; the "Simpan draf (gambar tidak
disimpan)" label keeps this honest at the point of loss rather than a
silent surprise on restore. Revisit as an additive, backward-compatible
schema change (`image_paths` nullable column) if wanted later.

## Testing

- `DraftRepository` unit tests against an in-memory `sqflite` database
  (`databaseFactory = databaseFactoryFfi` / `sqflite_common_ffi` for the
  test environment, matching how this repo already avoids requiring a real
  device for logic tests).
- Widget tests: composer pre-fills from an existing draft row; `PopScope`
  dialog appears only when content is non-empty; each of the 3 dialog
  actions produces the right repository call + navigation outcome; submit
  success clears the draft row.

## Out of scope

- Drafts-list / drafts management screen (multiple saved drafts, browsing,
  manual delete outside the exit-dialog flow).
- Image persistence in drafts.
- Cross-device draft sync (this is purely local/on-device, same as the
  `shared_preferences` theme setting).
- Draft expiry/cleanup job (`updated_at` is stored but nothing reads it yet).
