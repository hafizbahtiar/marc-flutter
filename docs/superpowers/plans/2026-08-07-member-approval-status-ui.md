# Stage 11 Frontend Implementation Plan — Member Approval Status UI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Flutter client awareness of the backend's Stage 11 member-approval status: gate pending/rejected users to a clear status screen, let management approve/reject from a dedicated screen, and render the 3 new notification types without crashing.

**Architecture:** Content-level gating in `FeedPage` (no router changes for the gate itself — `myProfileProvider` is async, so the check lives where the data is already consumed), one new page for the management approve/reject flow, and small additive changes to two existing data models.

**Tech Stack:** Flutter, Riverpod (`FutureProvider`, `Provider`), `go_router`, `dio` (via the existing `dioProvider`/`ProfileRepository` pattern).

## Global Constraints

- All new user-facing strings are in Malay, matching every existing screen in this app.
- This codebase has no widget/unit tests for the Posts/Members/Notifications features (verified via `flutter analyze` + manual/contract testing against a real backend in prior stages, not `_test.go`-equivalent files — see `marc_flutter/TODO.md` Stage 10's own verification notes). This plan follows that same convention: verification is `flutter analyze` (must be 0 issues) + `dart format` (must be clean) + `flutter test` (existing suite must stay green) for every task; there is no new widget-test-writing step.
- Follow existing patterns exactly: `Skeletonizer` for list loading states, `RefreshIndicator.adaptive` + a `ListView` empty-state for empty lists, an error-card (`OutlinedButton` "Cuba lagi") for fetch failures, `MySnackBar.success`/`.error` for action feedback — all copied from `members_page.dart` and `notifications_page.dart`'s existing code, not reinvented.
- Do not touch `ios/Podfile.lock` or any file unrelated to this plan's scope.

---

### Task 1: Data & repository layer

**Files:**
- Modify: `lib/features/profile/profile_providers.dart` (entire file)
- Modify: `lib/features/posts/post_models.dart:118-151` (`AppNotification` class only)
- Modify: `lib/features/members/members_page.dart:7-12` (`_placeholderRow` const only)

**Interfaces:**
- Produces: `Profile.status` (`String`), `MemberRow.userId` (`String`), `MemberRow.status` (`String`), `pendingMembersProvider` (`FutureProvider<List<MemberRow>>`), `ProfileRepository.approveMember(String userId)` (`Future<void>`), `ProfileRepository.rejectMember(String userId)` (`Future<void>`), `AppNotification.postId` (now `String?`, was `String`), `AppNotification.isMemberPending`/`.isMemberApproved`/`.isMemberRejected` (`bool` getters).
- Consumed by: Task 2 (`Profile.status`), Task 3 (`MemberRow.userId/status`, `pendingMembersProvider`, `approveMember`/`rejectMember`), Task 4 (`pendingMembersProvider` indirectly via Task 3's page), Task 5 (`AppNotification.postId`/getters).

- [ ] **Step 1: Rewrite `lib/features/profile/profile_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';

class Profile {
  const Profile({
    required this.memberId,
    required this.email,
    required this.emailVerified,
    required this.status,
    required this.displayName,
    required this.phone,
    required this.roleKey,
    required this.roleName,
    required this.category,
  });

  final String memberId;
  final String email;
  final bool emailVerified;
  final String status;
  final String? displayName;
  final String? phone;
  final String roleKey;
  final String roleName;
  final String category;

  bool get isManagement => category == 'management';

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      memberId: json['member_id'] as String,
      email: json['email'] as String,
      emailVerified: (json['email_verified'] as bool?) ?? false,
      status: (json['status'] as String?) ?? 'approved',
      displayName: json['display_name'] as String?,
      phone: json['phone'] as String?,
      roleKey: (json['role_key'] as String?) ?? 'ahli',
      roleName: (json['role_name'] as String?) ?? 'Ahli',
      category: (json['category'] as String?) ?? 'ahli',
    );
  }
}

/// Profil user semasa. Reaktif pada status log masuk — jadi ia re-fetch
/// sebaik sahaja sesi wujud (tak perlu hot restart).
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return null;

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/me');
  return Profile.fromJson(res.data as Map<String, dynamic>);
});

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref),
);

class ProfileRepository {
  ProfileRepository(this._ref);
  final Ref _ref;

  /// Kemas kini display name & phone user semasa.
  Future<void> update({
    required String displayName,
    required String phone,
  }) async {
    final dio = _ref.read(dioProvider);
    await dio.patch('/me', data: {'display_name': displayName, 'phone': phone});

    _ref.invalidate(myProfileProvider);
    // membersProvider papar display_name yang sama — tanpa invalidate ni,
    // tab Ahli kekal papar nama lama sampai logout/restart (non-autoDispose,
    // cuma recompute bila isLoggedIn berubah).
    _ref.invalidate(membersProvider);
  }

  /// Luluskan pendaftaran ahli (Stage 11) — management sahaja, backend
  /// tolak 403 kalau bukan.
  Future<void> approveMember(String userId) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/members/$userId/approve');
    _ref.invalidate(membersProvider);
    _ref.invalidate(pendingMembersProvider);
  }

  /// Tolak pendaftaran ahli (Stage 11) — row KEKAL di backend (bukan
  /// padam), boleh diluluskan semula lain kali.
  Future<void> rejectMember(String userId) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/members/$userId/reject');
    _ref.invalidate(membersProvider);
    _ref.invalidate(pendingMembersProvider);
  }
}

class MemberRow {
  const MemberRow({
    required this.userId,
    required this.memberId,
    required this.displayName,
    required this.roleName,
    required this.category,
    required this.status,
  });

  final String userId;
  final String memberId;
  final String? displayName;
  final String roleName;
  final String category;
  final String status;

  factory MemberRow.fromJson(Map<String, dynamic> json) {
    return MemberRow(
      userId: json['user_id'] as String,
      memberId: json['member_id'] as String,
      displayName: json['display_name'] as String?,
      roleName: (json['role_name'] as String?) ?? 'Ahli',
      category: (json['category'] as String?) ?? 'ahli',
      status: (json['status'] as String?) ?? 'approved',
    );
  }
}

/// Senarai ahli. Backend tentukan siapa nampak apa: management → semua;
/// ahli biasa → diri sendiri sahaja.
final membersProvider = FutureProvider<List<MemberRow>>((ref) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return const [];

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/members');
  return (res.data as List)
      .map((m) => MemberRow.fromJson(m as Map<String, dynamic>))
      .toList();
});

/// Ahli status=pending sahaja (Stage 11) — untuk skrin approve/reject
/// management. Backend 403 kalau caller bukan management.
final pendingMembersProvider = FutureProvider<List<MemberRow>>((ref) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return const [];

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/members', queryParameters: {'status': 'pending'});
  return (res.data as List)
      .map((m) => MemberRow.fromJson(m as Map<String, dynamic>))
      .toList();
});
```

- [ ] **Step 2: Update `AppNotification` in `lib/features/posts/post_models.dart`**

Replace the existing `AppNotification` class (currently lines 118-151) with:

```dart
class AppNotification {
  const AppNotification({
    required this.id,
    required this.actorId,
    required this.type,
    required this.postId,
    required this.commentId,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String actorId;
  final String type;
  final String? postId;
  final String? commentId;
  final bool read;
  final DateTime createdAt;

  bool get isLike => type == 'post_like';
  bool get isComment => type == 'post_comment';
  bool get isMemberPending => type == 'member_pending';
  bool get isMemberApproved => type == 'member_approved';
  bool get isMemberRejected => type == 'member_rejected';

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      actorId: json['actor_id'] as String,
      type: json['type'] as String,
      postId: json['post_id'] as String?,
      commentId: json['comment_id'] as String?,
      read: json['read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
```

(Only `postId`'s declared type and its `fromJson` cast change — from `String`/`json['post_id'] as String` to `String?`/`json['post_id'] as String?` — plus the 3 new getters. Nothing else in this class changes.)

- [ ] **Step 3: Fix the now-broken placeholder in `lib/features/members/members_page.dart`**

`MemberRow` gained two required fields (`userId`, `status`), so the existing skeleton placeholder must supply them. Replace:

```dart
const _placeholderRow = MemberRow(
  memberId: 'MARC2026/08/0000',
  displayName: 'Nama Ahli',
  roleName: 'Ahli',
  category: 'ahli',
);
```

with:

```dart
const _placeholderRow = MemberRow(
  userId: '00000000-0000-0000-0000-000000000000',
  memberId: 'MARC2026/08/0000',
  displayName: 'Nama Ahli',
  roleName: 'Ahli',
  category: 'ahli',
  status: 'approved',
);
```

- [ ] **Step 4: Verify**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ && flutter test`
Expected: `flutter analyze` reports "No issues found!"; `dart format` reports no changed files; existing test suite passes unchanged (these files aren't covered by existing tests, so this just confirms no regression elsewhere).

- [ ] **Step 5: Commit**

```bash
git add lib/features/profile/profile_providers.dart lib/features/posts/post_models.dart lib/features/members/members_page.dart
git commit -m "Add member approval status to Profile/MemberRow, nullable postId on AppNotification"
```

---

### Task 2: Feed gate

**Files:**
- Modify: `lib/features/posts/feed_page.dart` (entire file)

**Interfaces:**
- Consumes: `myProfileProvider` (`FutureProvider<Profile?>`, from Task 1 — reads `Profile.status`).
- Produces: nothing consumed by later tasks (self-contained UI change).

- [ ] **Step 1: Rewrite `lib/features/posts/feed_page.dart`**

Add two imports (`app/theme.dart` for `AppColors`, `profile/profile_providers.dart` for `myProfileProvider`), add a gate check at the top of `build`, and add the new `_PendingStatusView` widget at the end of the file. Full file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/posts/widgets/post_card.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stage 11: user pending/rejected tak boleh akses Feed (backend 403
    // semua endpoint selain /me). Gate content-level di sini (bukan
    // router redirect) sebab myProfileProvider async — lihat design spec
    // untuk rasional penuh. Fail-open kalau /me gagal fetch (error state)
    // — jangan block user approved sebab isu rangkaian sekejap.
    final profileStatus = ref.watch(
      myProfileProvider.select((p) => p.valueOrNull?.status),
    );
    if (profileStatus != null && profileStatus != 'approved') {
      return _PendingStatusView(
        status: profileStatus,
        onRefresh: () => ref.refresh(myProfileProvider.future),
      );
    }

    final feed = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MARC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Ahli',
            onPressed: () => context.push('/members'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifikasi',
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/posts/new'),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: feed.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat feed.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.read(feedProvider.notifier).refresh(),
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (state) {
            if (state.posts.isEmpty) {
              return RefreshIndicator.adaptive(
                onRefresh: () => ref.read(feedProvider.notifier).refresh(),
                child: ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 100),
                      child: Center(
                        child: Text('Tiada post lagi. Jadi yang pertama!'),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () => ref.read(feedProvider.notifier).refresh(),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: state.posts.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.posts.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    );
                  }

                  final post = state.posts[index];
                  return PostCard(
                    post: post,
                    onTap: () => context.push('/posts/${post.id}'),
                    onToggleLike: () =>
                        ref.read(feedProvider.notifier).toggleLike(post),
                    onEdit: () => context.push('/posts/${post.id}'),
                    onDelete: () async {
                      final ok = await showConfirmDialog(
                        context,
                        title: 'Padam post',
                        message: 'Anda pasti mahu padam post ini?',
                        confirmLabel: 'Padam',
                        isDestructive: true,
                      );
                      if (!ok) return;
                      try {
                        await ref
                            .read(postRepositoryProvider)
                            .deletePost(post.id);
                        ref.read(feedProvider.notifier).removePost(post.id);
                      } catch (_) {
                        if (context.mounted) {
                          MySnackBar.error(context, 'Gagal padam post.');
                        }
                      }
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PendingStatusView extends StatelessWidget {
  const _PendingStatusView({required this.status, required this.onRefresh});

  final String status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';
    return Scaffold(
      appBar: AppBar(title: const Text('MARC')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRejected ? Icons.error_outline : Icons.hourglass_empty,
                  size: 48,
                  color: isRejected ? AppColors.error : AppColors.warning,
                ),
                const SizedBox(height: 16),
                Text(
                  isRejected
                      ? 'Pendaftaran anda tidak diluluskan. Sila hubungi pihak pengurusan MAIWP.'
                      : 'Pendaftaran anda sedang disemak oleh pihak pengurusan MAIWP.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: onRefresh,
                  child: const Text('Semak semula'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze && dart format --set-exit-if-changed lib/features/posts/feed_page.dart && flutter test`
Expected: clean, no issues, existing tests still pass.

- [ ] **Step 3: Commit**

```bash
git add lib/features/posts/feed_page.dart
git commit -m "Gate Feed content on member approval status (Stage 11)"
```

---

### Task 3: Pending members page

**Files:**
- Create: `lib/features/members/pending_members_page.dart`

**Interfaces:**
- Consumes: `pendingMembersProvider`, `profileRepositoryProvider` (`.approveMember`/`.rejectMember`), `MemberRow` (all from Task 1).
- Produces: `PendingMembersPage` (a `ConsumerWidget`), consumed by Task 4's router wiring.

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';
import 'package:skeletonizer/skeletonizer.dart';

const _placeholderPendingRow = MemberRow(
  userId: '00000000-0000-0000-0000-000000000000',
  memberId: 'MARC2026/08/0000',
  displayName: 'Nama Ahli',
  roleName: 'Ahli',
  category: 'ahli',
  status: 'pending',
);

class PendingMembersPage extends ConsumerWidget {
  const PendingMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingMembersProvider);

    Future<void> onRefresh() => ref.refresh(pendingMembersProvider.future);

    Future<void> handleApprove(MemberRow row) async {
      try {
        await ref.read(profileRepositoryProvider).approveMember(row.userId);
        if (context.mounted) {
          MySnackBar.success(context, '${row.memberId} diluluskan.');
        }
      } catch (_) {
        if (context.mounted) {
          MySnackBar.error(context, 'Gagal luluskan ahli.');
        }
      }
    }

    Future<void> handleReject(MemberRow row) async {
      try {
        await ref.read(profileRepositoryProvider).rejectMember(row.userId);
        if (context.mounted) {
          MySnackBar.success(context, '${row.memberId} ditolak.');
        }
      } catch (_) {
        if (context.mounted) {
          MySnackBar.error(context, 'Gagal tolak ahli.');
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ahli Pending')),
      body: SafeArea(
        child: pending.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: _PendingList(
              rows: List.filled(4, _placeholderPendingRow),
              onApprove: (_) {},
              onReject: (_) {},
            ),
          ),
          error: (e, _) => RefreshIndicator.adaptive(
            onRefresh: onRefresh,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 80,
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Gagal memuat senarai ahli pending.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(pendingMembersProvider),
                        child: const Text('Cuba lagi'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return RefreshIndicator.adaptive(
                onRefresh: onRefresh,
                child: ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: Text('Tiada ahli menunggu kelulusan.'),
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator.adaptive(
              onRefresh: onRefresh,
              child: _PendingList(
                rows: rows,
                onApprove: handleApprove,
                onReject: handleReject,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PendingList extends StatelessWidget {
  const _PendingList({
    required this.rows,
    required this.onApprove,
    required this.onReject,
  });

  final List<MemberRow> rows;
  final void Function(MemberRow row) onApprove;
  final void Function(MemberRow row) onReject;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _PendingTile(
        row: rows[i],
        onApprove: () => onApprove(rows[i]),
        onReject: () => onReject(rows[i]),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.row,
    required this.onApprove,
    required this.onReject,
  });

  final MemberRow row;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.fieldFill,
            child: Text(
              (row.displayName?.isNotEmpty ?? false)
                  ? row.displayName![0].toUpperCase()
                  : '?',
              style: const TextStyle(color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.displayName ?? '(Tiada nama)'),
                Text(
                  row.memberId,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.check_circle_outline,
              color: AppColors.accent,
            ),
            tooltip: 'Luluskan',
            onPressed: onApprove,
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
            tooltip: 'Tolak',
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze && dart format --set-exit-if-changed lib/features/members/pending_members_page.dart && flutter test`
Expected: clean. Note `PendingMembersPage` is not yet referenced anywhere (Task 4 wires it up) — an unreferenced public class is not a `flutter analyze` warning in this codebase's default lint config, so this should still be clean; if analyze does flag it, report as a concern rather than adding a suppression.

- [ ] **Step 3: Commit**

```bash
git add lib/features/members/pending_members_page.dart
git commit -m "Add PendingMembersPage (Stage 11 management approve/reject UI)"
```

---

### Task 4: Router + Members AppBar button

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `lib/features/members/members_page.dart`

**Interfaces:**
- Consumes: `PendingMembersPage` (Task 3), `myProfileProvider` (Task 1, for `.isManagement`).

- [ ] **Step 1: Add the route in `lib/app/router.dart`**

Add the import (alphabetically with the other `features/members` import — there's currently only `members_page.dart`, so add just below it):

```dart
import 'package:marc/features/members/members_page.dart';
import 'package:marc/features/members/pending_members_page.dart';
```

Add the route right after the existing `/members` route:

```dart
      GoRoute(path: '/members', builder: (_, _) => const MembersPage()),
      GoRoute(
        path: '/members/pending',
        builder: (_, _) => const PendingMembersPage(),
      ),
```

- [ ] **Step 2: Add the management-only AppBar button in `lib/features/members/members_page.dart`**

Add an import at the top of the file:

```dart
import 'package:go_router/go_router.dart';
```

(this file currently has no `go_router` import — needed for `context.push`)

Change the `AppBar` from:

```dart
      appBar: AppBar(title: const Text('Ahli')),
```

to:

```dart
      appBar: AppBar(
        title: const Text('Ahli'),
        actions: [
          if (ref.watch(myProfileProvider).valueOrNull?.isManagement ?? false)
            IconButton(
              icon: const Icon(Icons.pending_actions_outlined),
              tooltip: 'Ahli Pending',
              onPressed: () => context.push('/members/pending'),
            ),
        ],
      ),
```

(`myProfileProvider` is already imported in this file via `profile_providers.dart`; `MembersPage` is already a `ConsumerWidget` with `WidgetRef ref` in scope.)

- [ ] **Step 3: Verify**

Run: `flutter analyze && dart format --set-exit-if-changed lib/app/router.dart lib/features/members/members_page.dart && flutter test`
Expected: clean.

- [ ] **Step 4: Commit**

```bash
git add lib/app/router.dart lib/features/members/members_page.dart
git commit -m "Wire PendingMembersPage into router + Members AppBar (Stage 11)"
```

---

### Task 5: Notifications UI for new types

**Files:**
- Modify: `lib/features/notifications/notifications_page.dart`

**Interfaces:**
- Consumes: `AppNotification.postId` (now `String?`), `.isMemberPending`/`.isMemberApproved`/`.isMemberRejected` (from Task 1).

- [ ] **Step 1: Add an import**

```dart
import 'package:marc/features/posts/post_models.dart';
```

(needed to reference the `AppNotification` type explicitly in the new helper functions below — currently only reached transitively via `notifications_providers.dart`)

- [ ] **Step 2: Add 3 helper functions**

Add these as top-level private functions in `notifications_page.dart` (e.g. just above the `NotificationsPage` class):

```dart
IconData _iconFor(AppNotification n) {
  if (n.isLike) return Icons.favorite;
  if (n.isComment) return Icons.mode_comment_outlined;
  if (n.isMemberPending) return Icons.person_add_alt_outlined;
  if (n.isMemberApproved) return Icons.check_circle_outline;
  return Icons.cancel_outlined; // isMemberRejected
}

Color _colorFor(BuildContext context, AppNotification n) {
  if (n.isLike || n.isMemberRejected) return AppColors.error;
  if (n.isMemberApproved) return AppColors.accent;
  return Theme.of(context).colorScheme.primary; // comment, member_pending
}

String _titleFor(AppNotification n) {
  if (n.isLike) return 'Seseorang menyukai post anda';
  if (n.isComment) return 'Seseorang comment pada post anda';
  if (n.isMemberPending) return 'Ahli baru menunggu kelulusan anda';
  if (n.isMemberApproved) return 'Pendaftaran anda telah diluluskan.';
  return 'Pendaftaran anda tidak diluluskan.'; // isMemberRejected
}
```

- [ ] **Step 3: Replace the `ListTile` construction inside `itemBuilder`**

Replace:

```dart
                  final n = items[i];
                  return ListTile(
                    leading: Icon(
                      n.isLike ? Icons.favorite : Icons.mode_comment_outlined,
                      color: n.isLike
                          ? AppColors.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      n.isLike
                          ? 'Seseorang menyukai post anda'
                          : 'Seseorang comment pada post anda',
                      style: TextStyle(
                        fontWeight: n.read
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(relativeTime(n.createdAt)),
                    trailing: n.read
                        ? null
                        : Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: () {
                      if (!n.read) {
                        ref.read(notificationRepositoryProvider).markRead(n.id);
                      }
                      context.push('/posts/${n.postId}');
                    },
                  );
```

with:

```dart
                  final n = items[i];
                  return ListTile(
                    leading: Icon(_iconFor(n), color: _colorFor(context, n)),
                    title: Text(
                      _titleFor(n),
                      style: TextStyle(
                        fontWeight: n.read
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(relativeTime(n.createdAt)),
                    trailing: n.read
                        ? null
                        : Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: () {
                      if (!n.read) {
                        ref.read(notificationRepositoryProvider).markRead(n.id);
                      }
                      if (n.postId != null) {
                        context.push('/posts/${n.postId}');
                      }
                    },
                  );
```

- [ ] **Step 4: Verify**

Run: `flutter analyze && dart format --set-exit-if-changed lib/features/notifications/notifications_page.dart && flutter test`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/notifications_page.dart
git commit -m "Render member approval notification types (Stage 11)"
```

---

### Task 6: Verification sweep + docs

**Files:**
- Modify: `TODO.md` (mark Stage 11 frontend done)
- No code files modified in this task.

- [ ] **Step 1: Full repo sweep**

```bash
flutter analyze
dart format --set-exit-if-changed lib/
flutter test
```

Expected: `flutter analyze` — "No issues found!"; `dart format` — no output (nothing to reformat); `flutter test` — all existing tests pass (same count as before this plan started; this plan added no new test files, per the Global Constraints note on why).

- [ ] **Step 2: Manual reasoning check (no live device/backend run required for this task — already a known gap tracked separately)**

Read through the 5 implemented pieces once more against the design spec (`docs/superpowers/specs/2026-08-07-member-approval-status-ui-design.md`) and confirm each maps to a task:
- Feed gate (pending/rejected full-screen state, fail-open on error) — Task 2
- Pending approvals screen + management-only entry point — Tasks 3-4
- Notification rendering for the 3 new types, nullable `postId` tap-guard — Task 5
- Data model additions — Task 1

Note in the report if anything from the spec was missed.

- [ ] **Step 3: Update `TODO.md`**

In `TODO.md`, replace the Stage 11 section (currently reads "belum design", listing open questions) with a done write-up, following the exact style of the existing "Stage 10 — Posts feature UI" entry immediately above it in the same file (a short paragraph of what was built, referencing the design spec, then what's still open). Content:

```markdown
- **Stage 11 — Member approval status UI** ✅ (done)
  Design penuh di `docs/superpowers/specs/2026-08-07-member-approval-status-ui-design.md`.
  Feed content-gated (bukan router-level) bila `profile.status != 'approved'`
  — skrin "menunggu kelulusan"/"ditolak" dengan butang semak semula.
  `PendingMembersPage` baru (management-only, icon button kat AppBar
  Ahli) untuk approve/reject. `AppNotification.postId` kini nullable +
  3 jenis notification baru (`member_pending`/`member_approved`/
  `member_rejected`) dirender dengan icon/copy sendiri, tap-guard elak
  navigate ke post yang tak wujud.
```

Also remove the old "Stage 11 — Status pendaftaran ahli (approval MAIWP) — belum design" section (superseded by the above) and its 4 `- [ ]` bullets, since they're now implemented.

- [ ] **Step 4: Commit**

```bash
git add TODO.md
git commit -m "Stage 11 frontend: member approval status UI done"
```

## Self-Review Notes

- **Spec coverage:** data model changes (Task 1), Feed gate incl. fail-open-on-error behavior (Task 2), management approve/reject screen + entry point (Tasks 3-4), notification rendering + nullable postId fix (Task 5) — all covered. The spec's "out of scope" items (member_pending tap-to-navigate, router-level gating, ProfilePage changes, bulk-approve) are correctly absent from every task.
- **Cross-task dependency check:** unlike the backend plan, no task here deliberately leaves `flutter analyze` broken between tasks — Task 3 (new file) is created before Task 4 wires it into the router, so every task's own verification step is a real, clean check, not a "expected failure" step.
- **Known pre-existing gap, not this plan's job to close:** `marc_flutter/TODO.md` already tracks "Test app betul-betul di simulator/device" as an open item predating this plan — this plan's verification (analyze/format/test) matches that existing convention rather than introducing new device-testing scope.
