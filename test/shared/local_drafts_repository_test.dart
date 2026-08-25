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
