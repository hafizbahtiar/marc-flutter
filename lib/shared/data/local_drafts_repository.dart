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
