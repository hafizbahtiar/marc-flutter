# Stage 11 Frontend — Member Approval Status UI

Date: 2026-08-07
Status: approved for implementation

## Problem

The `marc_go` backend (Stage 11, already shipped) added a management-approval
gate: new registrations start `status: 'pending'` on `/me`, and every
endpoint except `GET`/`PATCH /me` returns 403 until a management user
approves them. The Flutter client has no awareness of this yet — a pending
or rejected user who logs in lands straight on the Feed, which then fails
every API call with 403 with no explanation. `GET /notifications` also now
returns `post_id: null` for three new notification types
(`member_pending`/`member_approved`/`member_rejected`), which the client's
`AppNotification.postId` (currently `String`, not `String?`) would crash
parsing.

This spec covers the client-side work: gating pending/rejected users out of
the app with a clear status screen, giving management a way to
approve/reject, and rendering the new notification types safely.

## Data model changes

`lib/features/profile/profile_providers.dart`:
- `Profile` gains `status` (`String`) and `userId` (`String`), parsed from
  `/me`'s `status`/... — **note:** `/me` does not currently return
  `user_id` in its JSON (only `member_id`, `email`, `status`, etc.) per the
  backend's `profileResponse` struct. `Profile.userId` is therefore NOT
  added — `/me` doesn't need it (the acting user is always implicit from
  the JWT). Only `MemberRow` needs a `userId`, since management acts on
  *other* users by id.
- `MemberRow` gains `userId` (`String`) and `status` (`String`), parsed
  from `/members`' `user_id`/`status` fields (both already present in the
  backend's `memberResponse` JSON).

`lib/features/posts/post_models.dart`:
- `AppNotification.postId` changes from `String` to `String?`.
- `AppNotification.commentId` stays `String?` (already nullable, unchanged).
- New getters: `isMemberPending` (`type == 'member_pending'`),
  `isMemberApproved` (`type == 'member_approved'`), `isMemberRejected`
  (`type == 'member_rejected'`).

## Feed gate (content-level, not router-level)

`lib/features/posts/feed_page.dart`'s `build` watches `myProfileProvider`.
Three cases:
- **Loading** (first fetch not yet resolved): show the existing loading
  spinner (matches current behavior — do not assume approved).
- **Data, `status != 'approved'`**: render `_PendingStatusView` instead of
  the normal `Scaffold` body — no AppBar action buttons (Ahli/Notifikasi),
  no FAB, just the status message + a "Semak semula" button that calls
  `ref.refresh(myProfileProvider.future)`.
  - `status == 'pending'`: hourglass icon, "Pendaftaran anda sedang disemak
    oleh pihak pengurusan MAIWP."
  - `status == 'rejected'`: warning icon, "Pendaftaran anda tidak
    diluluskan. Sila hubungi pihak pengurusan MAIWP."
- **Data, `status == 'approved'`**: normal Feed as it is today.
- **Error** (profile fetch failed): fail open — render the normal Feed
  rather than blocking on a status check that couldn't complete. This
  matches the existing fail-safe default elsewhere in this codebase
  (`verify_email_banner.dart`'s `profile.valueOrNull?.emailVerified ??
  true`) — an approved user with a transient `/me` failure should not be
  locked out of Feed by this gate; the Feed's own `feedProvider` calls
  will 403 and show their own existing error state if the user actually
  isn't approved.

This is a content-level gate, not a `go_router` redirect — chosen because
`myProfileProvider` is async (`FutureProvider`) while `go_router`'s
`redirect` callback needs synchronous state, and the existing codebase
precedent (email-verification, `/me`-fetch errors) is already
content-level inline states, not router guards. Since `/members` and
`/notifications` are only reachable via buttons on Feed's AppBar, hiding
those buttons when not approved is sufficient — no user-facing path to
those screens exists for a pending/rejected user (they'd still get a
clean 403 from the backend if they somehow deep-linked in, which the
existing error-card pattern in `members_page.dart`/`notifications_page.dart`
already handles reasonably, if not with Stage-11-specific copy).

`ProfilePage` is NOT gated — `/me` (GET+PATCH) works regardless of status
by design, so a pending/rejected user can still view/edit their own name
and phone, and log out, via the existing Profile tab.

## Management: pending approvals screen

New file `lib/features/members/pending_members_page.dart`:
- Fetches `GET /members?status=pending` via a new `pendingMembersProvider`
  (`FutureProvider<List<MemberRow>>`, same shape/pattern as the existing
  `membersProvider` in `profile_providers.dart`).
- Each row: member id, display name, an **Approve** and a **Reject**
  button (`OutlinedButton`/`FilledButton`, following this codebase's
  existing button conventions).
- Approve/Reject call `ProfileRepository.approveMember(userId)` /
  `.rejectMember(userId)` (new methods, `POST /members/:id/approve` /
  `/reject`), then invalidate both `pendingMembersProvider` and
  `membersProvider` (so the main Ahli list picks up the new status too),
  and show a `MySnackBar.success` confirmation.
- Empty state: "Tiada ahli menunggu kelulusan." (matches
  `members_page.dart`'s existing empty-state pattern).
- Loading/error states follow `members_page.dart`'s existing
  Skeletonizer/error-card precedent.

`lib/features/members/members_page.dart`'s `AppBar` gains one
`IconButton` (e.g. `Icons.pending_actions_outlined`, tooltip "Ahli
Pending"), visible only when `ref.watch(myProfileProvider).valueOrNull
?.isManagement == true`, navigating to a new route.

`lib/app/router.dart` gains one route:
`GoRoute(path: '/members/pending', builder: (_, _) => const
PendingMembersPage())`.

## Notifications

`lib/features/notifications/notifications_page.dart`'s `itemBuilder`:
- Icon/title branch on the 3 new types, alongside the existing
  like/comment branches:
  - `member_pending`: `Icons.person_add_alt_outlined`, "Ahli baru
    menunggu kelulusan anda" (management-facing copy — only management
    ever receives this type).
  - `member_approved`: `Icons.check_circle_outline`, "Pendaftaran anda
    telah diluluskan."
  - `member_rejected`: `Icons.cancel_outlined`, "Pendaftaran anda tidak
    diluluskan."
- Tap handler: only calls `context.push('/posts/${n.postId}')` when
  `n.postId != null` (i.e. `isLike`/`isComment` types). For the 3 new
  types, tapping just marks the notification read (no navigation target —
  there's no post to show). `member_pending` could reasonably navigate to
  `/members/pending`, but that's deferred as a nice-to-have, not required
  for this stage (out of scope below).

## Out of scope

- Navigating from a tapped `member_pending` notification straight to the
  pending-approvals screen (falls back to "just mark read", matching how
  the app already handles notification types with no obvious navigation
  target).
- Router-level redirect gating (see "Feed gate" rationale above for why
  content-level was chosen instead).
- Any change to `ProfilePage`'s existing email-verification banner —
  unrelated to this stage, unaffected by it.
- Bulk-approve UI, search/filter within the pending list — matches the
  backend spec's own "out of scope" list (no bulk-approve endpoint
  exists to build UI for).
