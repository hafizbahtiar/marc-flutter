import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/activities/activity_models.dart';
import 'package:marc/features/activities/manage/activity_draft.dart';

Activity _activity({
  int? capacity = 30,
  DateTime? opensAt,
  int threshold = 100,
  List<ActivitySession> sessions = const [],
}) => Activity(
  id: 'a1',
  title: 'Kejohanan Badminton',
  description: 'Terbuka kepada semua ahli.',
  categoryId: 'c1',
  categoryName: 'Sukan',
  locationName: 'Dewan A',
  locationAddress: 'Jalan 1',
  startsAt: DateTime.utc(2099, 1, 1, 1),
  endsAt: DateTime.utc(2099, 1, 1, 4),
  registrationClosesAt: DateTime.utc(2098, 12, 1),
  registrationOpensAt: opensAt,
  capacity: capacity,
  registrationCount: 5,
  status: 'published',
  sessions: sessions,
  isRegistered: false,
  attendanceThresholdPct: threshold,
);

ActivitySession _session({
  required int seq,
  String title = '',
  required DateTime startsAt,
  required DateTime endsAt,
}) => ActivitySession(
  id: 's$seq',
  seq: seq,
  title: title,
  startsAt: startsAt,
  endsAt: endsAt,
);

void main() {
  group('buildActivityPatch - hanya medan yang BERUBAH', () {
    test('tiada suntingan → badan kosong, jadi tiada PATCH dihantar', () {
      final before = ActivityDraft.fromActivity(_activity());
      final after = before.copy();

      expect(buildActivityPatch(before, after), isEmpty);
    });

    test('satu medan disunting → hanya medan itu dalam badan', () {
      final before = ActivityDraft.fromActivity(_activity());
      final after = before.copy()..title = 'Kejohanan Badminton 2099';

      final patch = buildActivityPatch(before, after);

      // INI ujian yang memagar kelakuan gabungan backend: menghantar
      // semula keseluruhan objek "berfungsi" hari ini tetapi menulis ganti
      // suntingan pengurus lain yang mendarat antara muat dan simpan.
      expect(patch.keys, ['title']);
      expect(patch['title'], 'Kejohanan Badminton 2099');
      expect(patch.containsKey('description'), isFalse);
      expect(patch.containsKey('capacity'), isFalse);
      expect(patch.containsKey('category_id'), isFalse);
      expect(patch.containsKey('registration_closes_at'), isFalse);
      expect(patch.containsKey('attendance_threshold_pct'), isFalse);
    });

    test('ruang kosong sekeliling sahaja bukan perubahan', () {
      final before = ActivityDraft.fromActivity(_activity());
      final after = before.copy()..title = '  Kejohanan Badminton  ';

      expect(buildActivityPatch(before, after), isEmpty);
    });

    test('kapasiti dikosongkan → null EKSPLISIT (buang had), bukan '
        'ditinggalkan', () {
      final before = ActivityDraft.fromActivity(_activity(capacity: 30));
      final after = before.copy()..capacity = null;

      final patch = buildActivityPatch(before, after);

      expect(patch.containsKey('capacity'), isTrue);
      expect(patch['capacity'], isNull);
    });

    test('tarikh buka pendaftaran dibuang → null EKSPLISIT', () {
      final before = ActivityDraft.fromActivity(
        _activity(opensAt: DateTime.utc(2098, 11, 1)),
      );
      final after = before.copy()..registrationOpensAt = null;

      final patch = buildActivityPatch(before, after);

      expect(patch.containsKey('registration_opens_at'), isTrue);
      expect(patch['registration_opens_at'], isNull);
    });

    test('tarikh yang sama detik (zon berbeza) bukan perubahan', () {
      final before = ActivityDraft.fromActivity(_activity());
      final after = before.copy()
        ..registrationClosesAt = before.registrationClosesAt!.toLocal();

      expect(buildActivityPatch(before, after), isEmpty);
    });

    test('tarikh tutup ditukar → dihantar sebagai RFC3339 UTC', () {
      final before = ActivityDraft.fromActivity(_activity());
      final after = before.copy()
        ..registrationClosesAt = DateTime.utc(2098, 12, 5, 8, 30);

      final patch = buildActivityPatch(before, after);

      expect(patch.keys, ['registration_closes_at']);
      expect(patch['registration_closes_at'], '2098-12-05T08:30:00.000Z');
    });

    test('beberapa medan berubah → tepat medan itu sahaja', () {
      final before = ActivityDraft.fromActivity(_activity(threshold: 100));
      final after = before.copy()
        ..attendanceThresholdPct = 75
        ..locationName = 'Dewan B';

      final patch = buildActivityPatch(before, after);

      expect(
        patch,
        {'location_name': 'Dewan B', 'attendance_threshold_pct': 75},
      );
    });
  });

  group('sessionsChanged - gerbang bagi PUT sesi', () {
    final start = DateTime.utc(2099, 1, 1, 1);
    final end = DateTime.utc(2099, 1, 1, 4);

    List<SessionDraft> loaded() => [
      SessionDraft.fromSession(
        _session(seq: 1, title: 'Sesi pagi', startsAt: start, endsAt: end),
      ),
    ];

    test('set yang sama → tiada PUT (yang akan ditolak 409 bila ada '
        'kehadiran)', () {
      expect(sessionsChanged(loaded(), loaded()), isFalse);
    });

    test('tajuk sesi disunting → PUT diperlukan', () {
      final after = loaded()..first.title = 'Sesi petang';
      expect(sessionsChanged(loaded(), after), isTrue);
    });

    test('sesi ditambah → PUT diperlukan', () {
      final after = loaded()
        ..add(
          SessionDraft(
            startsAt: start.add(const Duration(days: 1)),
            endsAt: end.add(const Duration(days: 1)),
          ),
        );
      expect(sessionsChanged(loaded(), after), isTrue);
    });

    test('sesi dibuang → PUT diperlukan', () {
      expect(sessionsChanged(loaded(), const []), isTrue);
    });

    test('susunan senarai berbeza tetapi sesi yang sama → BUKAN perubahan',
        () {
      // Aktiviti lama boleh ada `seq` yang tidak mengikut kronologi. Kalau
      // itu dikira sebagai perubahan, membuka borang dan menekan Simpan
      // akan menghantar PUT yang tidak diminta - dan ditolak 409 sebaik ada
      // kehadiran.
      final a = SessionDraft(
        title: 'Pagi',
        startsAt: start,
        endsAt: end,
      );
      final b = SessionDraft(
        title: 'Petang',
        startsAt: start.add(const Duration(days: 1)),
        endsAt: end.add(const Duration(days: 1)),
      );

      expect(sessionsChanged([a, b], [b.copy(), a.copy()]), isFalse);
    });
  });

  group('buildSessionsList - seq daripada kedudukan', () {
    test('nombor urutan 1..n dan tidak pernah berulang', () {
      final start = DateTime.utc(2099, 1, 1, 1);
      final sessions = [
        for (var i = 0; i < 3; i++)
          SessionDraft(
            title: '  Sesi $i  ',
            startsAt: start.add(Duration(days: i)),
            endsAt: start.add(Duration(days: i, hours: 3)),
          ),
      ];

      final json = buildSessionsList(sessions);

      expect(json.map((s) => s['seq']), [1, 2, 3]);
      expect(json.first['title'], 'Sesi 0');
      expect(json.first['starts_at'], '2099-01-01T01:00:00.000Z');
    });

    test('seq mengikut KRONOLOGI, bukan urutan taip', () {
      final start = DateTime.utc(2099, 1, 10, 1);
      // Ditambah terakhir tetapi berlaku dahulu - pemilih kehadiran melabel
      // "Sesi ${seq}", jadi urutan taip akan membacanya sebagai sesi
      // terakhir pada pagi pertama kursus.
      final sessions = [
        SessionDraft(
          title: 'Kedua',
          startsAt: start,
          endsAt: start.add(const Duration(hours: 3)),
        ),
        SessionDraft(
          title: 'Pertama',
          startsAt: start.subtract(const Duration(days: 3)),
          endsAt: start.subtract(const Duration(days: 3, hours: -3)),
        ),
      ];

      final json = buildSessionsList(sessions);

      expect(json.map((s) => s['title']), ['Pertama', 'Kedua']);
      expect(json.map((s) => s['seq']), [1, 2]);
    });

    test('senarai pemanggil tidak diubah oleh penyusunan', () {
      final start = DateTime.utc(2099, 1, 10, 1);
      final sessions = [
        SessionDraft(title: 'B', startsAt: start, endsAt: start),
        SessionDraft(
          title: 'A',
          startsAt: start.subtract(const Duration(days: 1)),
          endsAt: start,
        ),
      ];

      buildSessionsList(sessions);

      expect(sessions.map((s) => s.title), ['B', 'A']);
    });
  });

  group('validateDraft', () {
    SessionDraft okSession() => SessionDraft(
      startsAt: DateTime.utc(2099, 1, 1, 1),
      endsAt: DateTime.utc(2099, 1, 1, 4),
    );

    ActivityDraft okDraft() => ActivityDraft.fromActivity(_activity());

    test('draf lengkap lulus', () {
      expect(validateDraft(okDraft(), [okSession()]), isNull);
    });

    test('tanpa sesi ditolak - backend juga menolaknya 400', () {
      expect(validateDraft(okDraft(), const []), isNotNull);
    });

    test('sesi terbalik ditolak dengan nombor sesi dalam mesej', () {
      final bad = SessionDraft(
        startsAt: DateTime.utc(2099, 1, 1, 4),
        endsAt: DateTime.utc(2099, 1, 1, 1),
      );
      expect(validateDraft(okDraft(), [okSession(), bad]), contains('Sesi 2'));
    });

    test('kapasiti sifar ditolak, kapasiti null (tiada had) diterima', () {
      expect(
        validateDraft(okDraft()..capacity = 0, [okSession()]),
        isNotNull,
      );
      expect(
        validateDraft(okDraft()..capacity = null, [okSession()]),
        isNull,
      );
    });

    test('ambang kehadiran di luar 1..100 ditolak', () {
      expect(
        validateDraft(okDraft()..attendanceThresholdPct = 0, [okSession()]),
        isNotNull,
      );
      expect(
        validateDraft(okDraft()..attendanceThresholdPct = 101, [okSession()]),
        isNotNull,
      );
    });

    test('tanpa kategori / tajuk / tarikh tutup ditolak', () {
      expect(validateDraft(okDraft()..categoryId = '', [okSession()]), isNotNull);
      expect(validateDraft(okDraft()..title = '   ', [okSession()]), isNotNull);
      expect(
        validateDraft(okDraft()..registrationClosesAt = null, [okSession()]),
        isNotNull,
      );
    });
  });

  test('buildCreateBody membawa sesi dalam badan yang sama', () {
    final body = buildCreateBody(ActivityDraft.fromActivity(_activity()), [
      SessionDraft(
        startsAt: DateTime.utc(2099, 1, 1, 1),
        endsAt: DateTime.utc(2099, 1, 1, 4),
      ),
    ]);

    expect(body['category_id'], 'c1');
    expect(body['capacity'], 30);
    expect(body['attendance_threshold_pct'], 100);
    expect((body['sessions'] as List).length, 1);
    // Tiada tarikh buka eksplisit → kunci itu TIDAK dihantar langsung.
    expect(body.containsKey('registration_opens_at'), isFalse);
  });
}
