# Local Post/Comment Drafts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist unsent post/comment content locally (sqflite) so it survives navigation and app kill, with a Twitter-style "Simpan draf / Buang / Batal" prompt on exit and silent auto-restore on reopen.

**Architecture:** A single sqflite table (`drafts`) behind a small `DraftRepository` interface, exposed via a Riverpod provider. Both composers (`create_post_page.dart`, the comment/reply composer in `post_detail_page.dart`) wrap their `Scaffold` in `PopScope`, intercept the exit attempt when there's unsaved content, and drive the repository from the resulting dialog choice. No autosave-while-typing - writes only happen at exit-with-confirmation or on successful submit (clears the draft).

**Tech Stack:** `sqflite` (storage), `path` (path joining), `sqflite_common_ffi` (dev-only, for running repository/db tests without a device), existing `flutter_riverpod` + the app's `AppDialogShell`/`showAppDialog` dialog system.

**Spec:** `docs/superpowers/specs/2026-08-25-post-comment-drafts-design.md`

## Global Constraints

- Text-only drafts (no image persistence) - v1 explicitly excludes it per spec.
- One overwritable slot per draft key - no drafts-list/management UI.
- No autosave-while-typing - writes happen only at exit-confirmation time or on successful submit.
- Draft keys: `'new_post'` (post composer, fixed); `'reply:{postId}:{parentCommentId ?? "root"}'` (comment composer).
- Auto-restore is silent (no "resume draft?" prompt) - pre-fill the field directly.
- **Do NOT run `git commit` for any step in this plan unless the user explicitly asks in that moment.** Each task below ends with a "Stop for review" step instead of a commit step - leave the working tree as-is and wait.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/local_db.dart` | Opens/creates the single local sqlite database + `drafts` table (create-only, no migrations yet). |
| `lib/shared/local_drafts_repository.dart` | `Draft` model, `DraftRepository` interface, `SqfliteDraftRepository` implementation, `draftRepositoryProvider`. |
| `test/support/fake_draft_repository.dart` | In-memory `DraftRepository` fake for widget tests (avoids touching sqlite/platform channels in fast widget tests). |
| `lib/features/posts/create_post_page.dart` | Modify: add `PopScope` + exit dialog + draft restore/clear. |
| `lib/features/posts/post_detail_page.dart` | Modify: same pattern for the inline comment/reply composer. |
| `test/core/local_db_test.dart` | New. |
| `test/shared/local_drafts_repository_test.dart` | New. |
| `test/features/posts/create_post_page_test.dart` | Modify: override `draftRepositoryProvider`; add draft-behavior tests. |
| `test/features/posts/post_detail_page_test.dart` | New. |

---

### Task 1: Local database bootstrap

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/local_db.dart`
- Test: `test/core/local_db_test.dart`

**Interfaces:**
- Produces: `Future<Database> openLocalDb()` - memoized, returns the same open `Database` instance on repeated calls. `Database` is `sqflite`'s type, re-exported by importing `package:sqflite/sqflite.dart`.

- [ ] **Step 1: Add dependencies**

In `pubspec.yaml`, under `dependencies:` (near the other storage-adjacent packages, after `shared_preferences`):

```yaml
  sqflite: ^2.4.2
  path: ^1.9.1
```

Under `dev_dependencies:` (after `flutter_lints`):

```yaml
  sqflite_common_ffi: ^2.3.6
```

Run: `flutter pub get`
Expected: resolves cleanly, `pubspec.lock` updated.

- [ ] **Step 2: Write the failing test**

Create `test/core/local_db_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('openLocalDb mencipta jadual drafts dengan lajur yang betul', () async {
    final db = await openLocalDb();

    final columns = await db.rawQuery('PRAGMA table_info(drafts)');
    final columnNames = columns.map((c) => c['name'] as String).toSet();

    expect(
      columnNames,
      {'key', 'kind', 'content', 'is_announcement', 'updated_at'},
    );
  });

  test('openLocalDb pulangkan instance Database yang sama bila dipanggil dua kali', () async {
    final first = await openLocalDb();
    final second = await openLocalDb();

    expect(identical(first, second), isTrue);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/local_db_test.dart`
Expected: FAIL with "Error: Not found: 'package:marc/core/local_db.dart'" (file doesn't exist yet).

- [ ] **Step 4: Write minimal implementation**

Create `lib/core/local_db.dart`:

```dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Future<Database>? _db;

/// Buka (atau pulangkan yang dah dibuka) pangkalan data SQLite tempatan
/// app - SATU fail dikongsi semua ciri storan setempat (drafts, dan apa
/// jua akan datang), padanan corak `dioProvider` di sisi rangkaian.
Future<Database> openLocalDb() => _db ??= _open();

Future<Database> _open() async {
  final dir = await getDatabasesPath();
  final path = join(dir, 'marc_local.db');
  return openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        create table drafts (
          key text primary key,
          kind text not null,
          content text not null,
          is_announcement integer,
          updated_at text not null
        )
      ''');
    },
  );
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/local_db_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Stop for review (no commit - wait for explicit request)**

---

### Task 2: Draft repository (sqflite-backed)

**Files:**
- Create: `lib/shared/local_drafts_repository.dart`
- Test: `test/shared/local_drafts_repository_test.dart`

**Interfaces:**
- Consumes: `openLocalDb()` from Task 1 (production provider only - the test constructs its own isolated in-memory `Database` directly, bypassing `openLocalDb()`).
- Produces:
  - `class Draft { final String key; final String kind; final String content; final bool? isAnnouncement; }`
  - `abstract class DraftRepository { Future<Draft?> get(String key); Future<void> save(String key, {required String kind, required String content, bool? isAnnouncement}); Future<void> delete(String key); }`
  - `class SqfliteDraftRepository implements DraftRepository` - constructor `SqfliteDraftRepository(Future<Database> dbFuture)`.
  - `final draftRepositoryProvider = Provider<DraftRepository>(...)`.

- [ ] **Step 1: Write the failing test**

Create `test/shared/local_drafts_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/local_drafts_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late SqfliteDraftRepository repo;

  setUp(() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute('''
          create table drafts (
            key text primary key,
            kind text not null,
            content text not null,
            is_announcement integer,
            updated_at text not null
          )
        '''),
      ),
    );
    repo = SqfliteDraftRepository(Future.value(db));
  });

  test('get pulangkan null bila tiada draf untuk key tu', () async {
    expect(await repo.get('new_post'), isNull);
  });

  test('save lepas tu get pulangkan draf yang sama', () async {
    await repo.save(
      'new_post',
      kind: 'post',
      content: 'Assalamualaikum',
      isAnnouncement: true,
    );

    final draft = await repo.get('new_post');

    expect(draft, isNotNull);
    expect(draft!.key, 'new_post');
    expect(draft.kind, 'post');
    expect(draft.content, 'Assalamualaikum');
    expect(draft.isAnnouncement, isTrue);
  });

  test('isAnnouncement null (draf comment) kekal null lepas roundtrip', () async {
    await repo.save('reply:p1:root', kind: 'comment', content: 'Setuju!');

    final draft = await repo.get('reply:p1:root');

    expect(draft!.isAnnouncement, isNull);
  });

  test('save dgn key sama menimpa draf lama (upsert), bukan tambah row baru', () async {
    await repo.save('new_post', kind: 'post', content: 'draf pertama');
    await repo.save('new_post', kind: 'post', content: 'draf kedua');

    final draft = await repo.get('new_post');

    expect(draft!.content, 'draf kedua');
  });

  test('delete buang draf - get lepas tu pulangkan null', () async {
    await repo.save('new_post', kind: 'post', content: 'nak dibuang');
    await repo.delete('new_post');

    expect(await repo.get('new_post'), isNull);
  });

  test('delete key yang tak wujud - tak throw', () async {
    await expectLater(repo.delete('tiada-key-ni'), completes);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/local_drafts_repository_test.dart`
Expected: FAIL with "Error: Not found: 'package:marc/shared/local_drafts_repository.dart'".

- [ ] **Step 3: Write minimal implementation**

Create `lib/shared/local_drafts_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/local_db.dart';
import 'package:sqflite/sqflite.dart';

class Draft {
  const Draft({
    required this.key,
    required this.kind,
    required this.content,
    this.isAnnouncement,
  });

  final String key;
  final String kind;
  final String content;
  final bool? isAnnouncement;
}

/// Storan draf post/comment yang belum dihantar - lihat spec
/// `docs/superpowers/specs/2026-08-25-post-comment-drafts-design.md`.
/// SATU row per `key` (upsert), bukan senarai draf.
abstract class DraftRepository {
  Future<Draft?> get(String key);

  Future<void> save(
    String key, {
    required String kind,
    required String content,
    bool? isAnnouncement,
  });

  Future<void> delete(String key);
}

class SqfliteDraftRepository implements DraftRepository {
  SqfliteDraftRepository(this._dbFuture);

  final Future<Database> _dbFuture;

  @override
  Future<Draft?> get(String key) async {
    final db = await _dbFuture;
    final rows = await db.query('drafts', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;

    final row = rows.first;
    final rawAnnouncement = row['is_announcement'] as int?;
    return Draft(
      key: row['key'] as String,
      kind: row['kind'] as String,
      content: row['content'] as String,
      isAnnouncement: rawAnnouncement == null ? null : rawAnnouncement == 1,
    );
  }

  @override
  Future<void> save(
    String key, {
    required String kind,
    required String content,
    bool? isAnnouncement,
  }) async {
    final db = await _dbFuture;
    await db.insert('drafts', {
      'key': key,
      'kind': kind,
      'content': content,
      'is_announcement': isAnnouncement == null
          ? null
          : (isAnnouncement ? 1 : 0),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> delete(String key) async {
    final db = await _dbFuture;
    await db.delete('drafts', where: 'key = ?', whereArgs: [key]);
  }
}

final draftRepositoryProvider = Provider<DraftRepository>((ref) {
  return SqfliteDraftRepository(openLocalDb());
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/local_drafts_repository_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Stop for review (no commit - wait for explicit request)**

---

### Task 3: Fake draft repository for widget tests

**Why this task exists:** `create_post_page.dart`/`post_detail_page.dart` will call `ref.read(draftRepositoryProvider)` from `initState`. In a plain `flutter_test` widget test (no device, no FFI setup), the real `SqfliteDraftRepository` would hit the sqlite platform channel and throw `MissingPluginException`. Widget tests override `draftRepositoryProvider` with this in-memory fake instead - no sqlite involved, fast, isolated per test.

**Files:**
- Create: `test/support/fake_draft_repository.dart`

**Interfaces:**
- Consumes: `DraftRepository`, `Draft` from `package:marc/shared/local_drafts_repository.dart` (Task 2).
- Produces: `class FakeDraftRepository implements DraftRepository` - no constructor args, starts empty.

- [ ] **Step 1: Write the failing test**

This is test-support code, not production code - its "test" is a short self-check that the fake actually satisfies the same contract the real repository does. Create `test/support/fake_draft_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/local_drafts_repository.dart';

import 'fake_draft_repository.dart';

void main() {
  test('FakeDraftRepository: get/save/delete roundtrip macam repo sebenar', () async {
    final repo = FakeDraftRepository();

    expect(await repo.get('k'), isNull);

    await repo.save('k', kind: 'post', content: 'hai', isAnnouncement: false);
    final draft = await repo.get('k');
    expect(draft!.content, 'hai');
    expect(draft.isAnnouncement, isFalse);

    await repo.delete('k');
    expect(await repo.get('k'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/support/fake_draft_repository_test.dart`
Expected: FAIL with "Error: Not found: 'fake_draft_repository.dart'".

- [ ] **Step 3: Write minimal implementation**

Create `test/support/fake_draft_repository.dart`:

```dart
import 'package:marc/shared/local_drafts_repository.dart';

/// Fake dalam-memori [DraftRepository] untuk widget test - elak sentuh
/// sqlite/platform channel langsung dalam ujian yang bukan tentang storan
/// itu sendiri. Lihat `test/shared/local_drafts_repository_test.dart`
/// untuk ujian storan SEBENAR (sqflite_common_ffi).
class FakeDraftRepository implements DraftRepository {
  final Map<String, Draft> _store = {};

  @override
  Future<Draft?> get(String key) async => _store[key];

  @override
  Future<void> save(
    String key, {
    required String kind,
    required String content,
    bool? isAnnouncement,
  }) async {
    _store[key] = Draft(
      key: key,
      kind: kind,
      content: content,
      isAnnouncement: isAnnouncement,
    );
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/support/fake_draft_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Stop for review (no commit - wait for explicit request)**

---

### Task 4: Wire drafts into the new-post composer

**Files:**
- Modify: `lib/features/posts/create_post_page.dart`
- Modify: `test/features/posts/create_post_page_test.dart`

**Interfaces:**
- Consumes: `draftRepositoryProvider`, `DraftRepository`, `Draft` (Task 2); `FakeDraftRepository` (Task 3); `AppDialogShell`/`AppDialogAction`/`showAppDialog` (existing, `lib/shared/widgets/app_dialog.dart`).
- Produces: no new public API - this is UI wiring only.

- [ ] **Step 1: Write the failing tests**

In `test/features/posts/create_post_page_test.dart`, add the import and update `_host()` to accept and apply a draft repository override (existing tests keep passing unchanged since `FakeDraftRepository()` starts empty - no unsaved-content dialog fires unless the test types something and tries to leave):

```dart
import 'package:marc/shared/local_drafts_repository.dart';

import '../../support/fake_draft_repository.dart';
```

Replace the existing `_host` function:

```dart
Widget _host({required bool management, DraftRepository? draftRepository}) =>
    ProviderScope(
      overrides: [
        myProfileProvider.overrideWith(
          (ref) async => _profile(management: management),
        ),
        draftRepositoryProvider.overrideWithValue(
          draftRepository ?? FakeDraftRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        // Dibungkus dengan skrin permulaan + push, supaya CreatePostPage
        // ada back button (Navigator.canPop true) untuk tester.pageBack()
        // uji gerak isyarat keluar.
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreatePostPage()),
            ),
            child: const Text('buka'),
          ),
        ),
      ),
    );

Future<void> _openComposer(WidgetTester tester, {required bool management}) async {
  await tester.pumpWidget(_host(management: management));
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}
```

**Every existing `testWidgets` in this file currently calls `tester.pumpWidget(_host(management: ...))` directly and expects `CreatePostPage` to already be on screen** - since `_host` now returns a launcher button instead, update every existing call site from:

```dart
await tester.pumpWidget(_host(management: false));
await tester.pumpAndSettle();
```

to:

```dart
await _openComposer(tester, management: false);
```

(and the `management: true` variants correspondingly). There are 6 call sites across the `butang hantar` and `pil pengumuman` groups - update all of them.

Then add a new group at the end of `main()`:

```dart
  group('draf', () {
    testWidgets('draf sedia ada auto-isi medan teks bila composer dibuka', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await repo.save('new_post', kind: 'post', content: 'draf lama saya');

      await _openComposer(tester, management: false);
      await tester.pumpWidget(_host(management: false, draftRepository: repo));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('draf lama saya'), findsOneWidget);
    });

    testWidgets('tiada dialog keluar bila composer kosong', (tester) async {
      await _openComposer(tester, management: false);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Simpan sebagai draf?'), findsNothing);
      expect(find.byType(CreatePostPage), findsNothing);
    });

    testWidgets('dialog keluar muncul bila ada teks belum dihantar, Batal kekalkan composer', (
      tester,
    ) async {
      await _openComposer(tester, management: false);
      await tester.enterText(find.byType(TextField), 'sedang menaip...');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Simpan sebagai draf?'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.byType(CreatePostPage), findsOneWidget);
      expect(find.text('sedang menaip...'), findsOneWidget);
    });

    testWidgets('pilih Simpan draf menulis ke repository dan tutup composer', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await _openComposer(tester, management: false);
      await tester.pumpWidget(_host(management: false, draftRepository: repo));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'simpan ni');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan draf'));
      await tester.pumpAndSettle();

      expect(find.byType(CreatePostPage), findsNothing);
      final saved = await repo.get('new_post');
      expect(saved!.content, 'simpan ni');
    });

    testWidgets('pilih Buang memadam draf sedia ada dan tutup composer tanpa simpan', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await repo.save('new_post', kind: 'post', content: 'draf lama');
      await tester.pumpWidget(_host(management: false, draftRepository: repo));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'draf lama diubah');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buang'));
      await tester.pumpAndSettle();

      expect(find.byType(CreatePostPage), findsNothing);
      expect(await repo.get('new_post'), isNull);
    });
  });
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `flutter test test/features/posts/create_post_page_test.dart`
Expected: the 6 pre-existing tests still PASS (host change is behavior-preserving); the 5 new `draf` tests FAIL - `draftRepositoryProvider` doesn't exist as an override target yet / `PopScope` behavior isn't wired, so no "Simpan sebagai draf?" dialog appears and `pageBack()` just pops immediately.

- [ ] **Step 3: Write minimal implementation**

In `lib/features/posts/create_post_page.dart`:

Add imports:

```dart
import 'package:marc/shared/local_drafts_repository.dart';
```

Add the draft key constant near the other top-level constants:

```dart
const _draftKey = 'new_post';
```

Add an exit-choice enum and confirm-dialog helper near the bottom of the file (after the last class):

```dart
enum _ExitDraftChoice { save, discard }

/// Dialog keluar gaya Twitter - tindakan simpan/buang gambar sengaja
/// diletak dalam mesej (bukan label butang): label butang mesti pendek
/// (lihat corak sedia ada showReasonDialog/showAppInputDialog).
Future<_ExitDraftChoice?> _confirmExitWithDraft(
  BuildContext context, {
  required bool hasImages,
}) {
  return showAppDialog<_ExitDraftChoice>(
    context,
    title: 'Simpan sebagai draf?',
    message: hasImages
        ? 'Anda ada kandungan belum dihantar. Gambar yang dipilih TIDAK '
              'disimpan dalam draf - pilih semula bila sambung nanti.'
        : 'Anda ada kandungan belum dihantar.',
    actions: (ctx) => [
      AppDialogAction(
        label: 'Batal',
        onPressed: () => Navigator.pop(ctx),
      ),
      AppDialogAction(
        label: 'Buang',
        isDestructive: true,
        onPressed: () => Navigator.pop(ctx, _ExitDraftChoice.discard),
      ),
      AppDialogAction(
        label: 'Simpan draf',
        isPrimary: true,
        onPressed: () => Navigator.pop(ctx, _ExitDraftChoice.save),
      ),
    ],
  );
}
```

In `_CreatePostPageState`, add `initState`:

```dart
  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final draft = await ref.read(draftRepositoryProvider).get(_draftKey);
    if (draft == null || !mounted) return;
    _contentController.text = draft.content;
    setState(() => _isAnnouncement = draft.isAnnouncement ?? false);
  }
```

Add the exit handler:

```dart
  bool get _hasUnsavedContent =>
      _contentController.text.trim().isNotEmpty || _images.isNotEmpty;

  Future<void> _handlePopAttempt(bool didPop, Object? result) async {
    if (didPop) return;
    final choice = await _confirmExitWithDraft(
      context,
      hasImages: _images.isNotEmpty,
    );
    if (choice == null || !mounted) return;

    final repo = ref.read(draftRepositoryProvider);
    if (choice == _ExitDraftChoice.save) {
      await repo.save(
        _draftKey,
        kind: 'post',
        content: _contentController.text.trim(),
        isAnnouncement: _isAnnouncement,
      );
    } else {
      await repo.delete(_draftKey);
    }
    if (mounted) Navigator.of(context).pop();
  }
```

In `_submit`, after the existing `ref.invalidate(feedProvider);` line, add:

```dart
      await ref.read(draftRepositoryProvider).delete(_draftKey);
```

Finally, wrap the returned widget: change

```dart
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
```

to:

```dart
    return PopScope(
      canPop: !_hasUnsavedContent,
      onPopInvokedWithPop: _handlePopAttempt,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
```

...and close the added `PopScope` with an extra `)` at the very end of `build`'s return statement (after the existing `Scaffold`'s closing `)`, `);` becomes `),\n    );`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/posts/create_post_page_test.dart`
Expected: PASS (11 tests: 6 pre-existing + 5 new).

- [ ] **Step 5: Run full analyzer + format check**

Run: `dart analyze lib/features/posts/create_post_page.dart test/features/posts/create_post_page_test.dart`
Expected: "No issues found!"

Run: `dart format --output=none --set-exit-if-changed lib/features/posts/create_post_page.dart test/features/posts/create_post_page_test.dart`
Expected: no diff.

- [ ] **Step 6: Stop for review (no commit - wait for explicit request)**

---

### Task 5: Wire drafts into the comment/reply composer

**Files:**
- Modify: `lib/features/posts/post_detail_page.dart`
- Create: `test/features/posts/post_detail_page_test.dart`

**Interfaces:**
- Consumes: same as Task 4, plus `Post`, `Comment`, `Author` (`lib/features/posts/post_models.dart`), `postDetailProvider`, `commentsProvider` (`lib/features/posts/post_providers.dart`).
- Produces: no new public API.

- [ ] **Step 1: Write the failing tests**

Create `test/features/posts/post_detail_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/posts/post_detail_page.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/local_drafts_repository.dart';

import '../../support/fake_draft_repository.dart';

Post _post() => Post(
  id: 'post-1',
  type: 'normal',
  content: 'Post asal',
  createdAt: DateTime(2026, 8, 25),
  editedAt: null,
  author: const Author(memberId: 'MARC2026/08/0002', displayName: 'Aina'),
  images: const [],
  likeCount: 0,
  commentCount: 0,
  likedByMe: false,
);

Profile _profile() => Profile(
  memberId: 'MARC2026/08/0001',
  email: 'a@b.com',
  emailVerified: true,
  status: 'approved',
  displayName: 'Hafiz',
  phone: null,
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: 10,
  category: 'ahli',
  telegramLinked: false,
);

Widget _host({DraftRepository? draftRepository}) => ProviderScope(
  overrides: [
    myProfileProvider.overrideWith((ref) async => _profile()),
    postDetailProvider.overrideWith((ref, id) async => _post()),
    commentsProvider.overrideWith((ref, id) async => const <Comment>[]),
    draftRepositoryProvider.overrideWithValue(
      draftRepository ?? FakeDraftRepository(),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PostDetailPage(postId: 'post-1')),
        ),
        child: const Text('buka'),
      ),
    ),
  ),
);

Future<void> _openPostDetail(WidgetTester tester) async {
  await tester.pumpWidget(_host());
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

void main() {
  group('draf comment', () {
    testWidgets('draf sedia ada untuk root auto-isi medan comment', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await repo.save('reply:post-1:root', kind: 'comment', content: 'draf balasan');

      await tester.pumpWidget(_host(draftRepository: repo));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('draf balasan'), findsOneWidget);
    });

    testWidgets('tiada dialog keluar bila medan comment kosong', (tester) async {
      await _openPostDetail(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Simpan sebagai draf?'), findsNothing);
      expect(find.byType(PostDetailPage), findsNothing);
    });

    testWidgets('pilih Simpan draf tulis ke key root dan tutup skrin', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await tester.pumpWidget(_host(draftRepository: repo));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'comment belum hantar');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan draf'));
      await tester.pumpAndSettle();

      expect(find.byType(PostDetailPage), findsNothing);
      final saved = await repo.get('reply:post-1:root');
      expect(saved!.content, 'comment belum hantar');
      expect(saved.kind, 'comment');
    });

    testWidgets('pilih Buang memadam draf dan tutup skrin tanpa simpan', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await tester.pumpWidget(_host(draftRepository: repo));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nak dibuang');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buang'));
      await tester.pumpAndSettle();

      expect(find.byType(PostDetailPage), findsNothing);
      expect(await repo.get('reply:post-1:root'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/posts/post_detail_page_test.dart`
Expected: FAIL - no `PopScope`/draft wiring exists yet in `PostDetailPage`, so no dialog appears and drafts are never written/read.

- [ ] **Step 3: Write minimal implementation**

In `lib/features/posts/post_detail_page.dart`:

Add import:

```dart
import 'package:marc/shared/local_drafts_repository.dart';
```

Add a draft-key getter and the same exit-choice plumbing as Task 4 to `_PostDetailPageState` (this duplicates the small `_ExitDraftChoice` enum + dialog helper from `create_post_page.dart` - both files are small, separate composers with slightly different copy needs (post vs comment context); a shared helper isn't worth the indirection for two call sites per YAGNI):

```dart
  String get _draftKey =>
      'reply:${widget.postId}:${_replyingTo?.id ?? "root"}';

  bool get _hasUnsavedComment => _commentController.text.trim().isNotEmpty;

  Future<void> _handlePopAttempt(bool didPop, Object? result) async {
    if (didPop) return;
    final choice = await _confirmExitWithDraft(context);
    if (choice == null || !mounted) return;

    final repo = ref.read(draftRepositoryProvider);
    if (choice == _ExitDraftChoice.save) {
      await repo.save(
        _draftKey,
        kind: 'comment',
        content: _commentController.text.trim(),
      );
    } else {
      await repo.delete(_draftKey);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _restoreDraft() async {
    final draft = await ref.read(draftRepositoryProvider).get(_draftKey);
    if (draft == null || !mounted) return;
    _commentController.text = draft.content;
  }
```

Add `initState`:

```dart
  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }
```

In `_sendComment`, after `_commentController.clear();`, add:

```dart
      await ref.read(draftRepositoryProvider).delete(_draftKey);
```

Add the module-level enum + dialog helper (same pattern as Task 4, comment-flavored copy) near the bottom of the file, after the last class:

```dart
enum _ExitDraftChoice { save, discard }

Future<_ExitDraftChoice?> _confirmExitWithDraft(BuildContext context) {
  return showAppDialog<_ExitDraftChoice>(
    context,
    title: 'Simpan sebagai draf?',
    message: 'Anda ada comment belum dihantar.',
    actions: (ctx) => [
      AppDialogAction(label: 'Batal', onPressed: () => Navigator.pop(ctx)),
      AppDialogAction(
        label: 'Buang',
        isDestructive: true,
        onPressed: () => Navigator.pop(ctx, _ExitDraftChoice.discard),
      ),
      AppDialogAction(
        label: 'Simpan draf',
        isPrimary: true,
        onPressed: () => Navigator.pop(ctx, _ExitDraftChoice.save),
      ),
    ],
  );
}
```

Also add the `app_dialog.dart` import:

```dart
import 'package:marc/shared/widgets/app_dialog.dart';
```

Finally, wrap `build`'s return: change

```dart
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
```

to:

```dart
    return PopScope(
      canPop: !_hasUnsavedComment,
      onPopInvokedWithPop: _handlePopAttempt,
      child: Scaffold(
        appBar: AppBar(title: const Text('Post')),
```

...and close the added `PopScope` with an extra `)` at the very end of `build`'s return statement.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/posts/post_detail_page_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Run the full posts test suite to check for regressions**

Run: `flutter test test/features/posts`
Expected: all PASS (existing `comment_tile_test.dart`, `feed_notifier_test.dart`, `post_image_grid_test.dart`, `create_post_page_test.dart` unaffected).

- [ ] **Step 6: Run analyzer + format check**

Run: `dart analyze lib/features/posts/post_detail_page.dart test/features/posts/post_detail_page_test.dart`
Expected: "No issues found!"

Run: `dart format --output=none --set-exit-if-changed lib/features/posts/post_detail_page.dart test/features/posts/post_detail_page_test.dart`
Expected: no diff.

- [ ] **Step 7: Full project sanity check**

Run: `dart analyze` (whole project)
Expected: "No issues found!"

- [ ] **Step 8: Stop for review (no commit - wait for explicit request)**

---

## Notes for the implementer

- `PopScope`'s `onPopInvokedWithPop` is `void Function(bool, T?)`, but assigning an `async` closure to it is idiomatic and already used throughout this codebase for `VoidCallback`-typed fields (e.g. every `onPressed: () async { ... }` in `create_post_page.dart`/`profile_page.dart`) - no special handling needed.
- The "gambar tidak disimpan" caveat lives in the exit dialog's **message**, not a button label - per this session's established convention (button text stays short; see the `app_dialog.dart` button-length cleanup earlier this session). This is a deliberate deviation from the spec's literal wording ("button label becomes...") in favor of that convention.
- `isAnnouncement` restore for a non-management user who somehow has an announcement draft (edge case: drafted while management, role changed since) is left as-is - the announcement toggle chip stays hidden for non-management regardless, and the backend independently gates `type: 'announcement'` by role, so no real exposure, just a UI no-op. Not worth extra handling for v1.
