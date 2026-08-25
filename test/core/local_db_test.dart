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
