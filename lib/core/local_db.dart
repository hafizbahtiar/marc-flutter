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
