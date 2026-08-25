import 'dart:async';

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

/// Fake [DraftRepository] yang sentiasa throw pada save/delete - guna
/// untuk uji laluan kegagalan storan tempatan dalam `_handlePopAttempt`
/// (create_post_page.dart / post_detail_page.dart). Kegagalan storan
/// TAK PATUT memerangkap pengguna pada skrin - lihat spec.
class ThrowingDraftRepository implements DraftRepository {
  @override
  Future<Draft?> get(String key) async => null;

  @override
  Future<void> save(
    String key, {
    required String kind,
    required String content,
    bool? isAnnouncement,
  }) async {
    throw Exception('simulated storage failure');
  }

  @override
  Future<void> delete(String key) async {
    throw Exception('simulated storage failure');
  }
}

/// Bungkus [DraftRepository] lain, tapi tangguhkan `get()` sehingga
/// [release] dipanggil.
///
/// Guna untuk uji regresi setState pada `_restoreDraft()`: provider lain
/// (post/comments) turut resolve secara async semasa pembukaan skrin, dan
/// rebuild YANG TAK BERKAITAN tu boleh secara tak sengaja "cover up" bug
/// hilang setState (canPop jadi betul secara kebetulan, bukan sebab
/// setState). Dengan menangguhkan get() sampai semua provider lain dah
/// settle (lepas `pumpAndSettle()` pembukaan), baru `release()`, kita
/// pastikan SATU-SATUNYA punca rebuild lepas draf dipulihkan ialah
/// `_restoreDraft()` itu sendiri.
class DelayedGetDraftRepository implements DraftRepository {
  DelayedGetDraftRepository(this._inner);

  final DraftRepository _inner;
  final _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<Draft?> get(String key) async {
    await _gate.future;
    return _inner.get(key);
  }

  @override
  Future<void> save(
    String key, {
    required String kind,
    required String content,
    bool? isAnnouncement,
  }) => _inner.save(
    key,
    kind: kind,
    content: content,
    isAnnouncement: isAnnouncement,
  );

  @override
  Future<void> delete(String key) => _inner.delete(key);
}
