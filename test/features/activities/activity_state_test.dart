import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/activities/activity_models.dart';

Activity buatAktiviti({
  int? capacity,
  int registrationCount = 0,
  bool isRegistered = false,
  String status = 'published',
  DateTime? tutup,
  DateTime? buka,
}) {
  final now = DateTime.now();
  return Activity(
    registrationOpensAt: buka,
    id: 'a1',
    title: 'Kejohanan Badminton',
    description: '',
    categoryId: 'c1',
    categoryName: 'Badminton',
    locationName: 'Dewan A',
    locationAddress: '',
    startsAt: now.add(const Duration(days: 7)),
    endsAt: now.add(const Duration(days: 7, hours: 3)),
    registrationClosesAt: tutup ?? now.add(const Duration(days: 5)),
    capacity: capacity,
    registrationCount: registrationCount,
    status: status,
    sessions: const [],
    isRegistered: isRegistered,
  );
}

void main() {
  test('boleh daftar bila ada slot dan masih terbuka', () {
    expect(buatAktiviti(capacity: 10, registrationCount: 3).canRegister, isTrue);
  });

  test('tak boleh daftar bila penuh', () {
    final a = buatAktiviti(capacity: 10, registrationCount: 10);
    expect(a.isFull, isTrue);
    expect(a.canRegister, isFalse);
  });

  test('kapasiti null bermakna tiada had', () {
    expect(buatAktiviti(registrationCount: 999).isFull, isFalse);
  });

  test('tak boleh daftar selepas tarikh tutup', () {
    final a = buatAktiviti(
      capacity: 10,
      tutup: DateTime.now().subtract(const Duration(hours: 1)),
    );
    expect(a.registrationClosed, isTrue);
    expect(a.canRegister, isFalse);
  });

  test('tak boleh daftar bila sudah berdaftar', () {
    expect(buatAktiviti(capacity: 10, isRegistered: true).canRegister, isFalse);
  });

  test('tak boleh daftar bila aktiviti dibatalkan', () {
    expect(buatAktiviti(capacity: 10, status: 'cancelled').canRegister, isFalse);
  });

  // Gerbang TUNGGAL. `canRegister` diterbitkan daripada
  // `registrationBlocker`, dan halaman detail memetakan enum yang sama
  // kepada teks - jadi ujian ini memagar kedua-duanya sekali gus.
  group('registrationBlocker satu gerbang untuk setiap status', () {
    test('published dan terbuka → tiada sekatan', () {
      expect(
        buatAktiviti(capacity: 10, registrationCount: 3).registrationBlocker,
        isNull,
      );
    });

    test('completed → tamat, BUKAN "belum dibuka"', () {
      // Regresi: tab "Lepas" penuh dengan aktiviti `completed` (backend
      // defaultListStatuses = published, cancelled, completed), dan versi
      // lama memaparkan "Pendaftaran belum dibuka." pada setiap satunya -
      // bertentangan dengan kebenaran.
      final a = buatAktiviti(capacity: 10, status: 'completed');
      expect(a.registrationBlocker, RegistrationBlocker.completed);
      expect(a.canRegister, isFalse);
    });

    test('cancelled → dibatalkan', () {
      expect(
        buatAktiviti(capacity: 10, status: 'cancelled').registrationBlocker,
        RegistrationBlocker.cancelled,
      );
    });

    test('draft → belum diterbitkan', () {
      expect(
        buatAktiviti(capacity: 10, status: 'draft').registrationBlocker,
        RegistrationBlocker.notPublished,
      );
    });

    test('registration_opens_at masih di masa depan → opensLater', () {
      final a = buatAktiviti(
        capacity: 10,
        buka: DateTime.now().add(const Duration(days: 1)),
      );
      expect(a.registrationBlocker, RegistrationBlocker.opensLater);
      expect(a.canRegister, isFalse);
    });

    test('registration_opens_at sudah berlalu tidak menyekat', () {
      final a = buatAktiviti(
        capacity: 10,
        buka: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(a.registrationBlocker, isNull);
      expect(a.canRegister, isTrue);
    });

    test('tetingkap tertutup → closed', () {
      expect(
        buatAktiviti(
          capacity: 10,
          tutup: DateTime.now().subtract(const Duration(hours: 1)),
        ).registrationBlocker,
        RegistrationBlocker.closed,
      );
    });

    test('penuh → full', () {
      expect(
        buatAktiviti(capacity: 10, registrationCount: 10).registrationBlocker,
        RegistrationBlocker.full,
      );
    });

    test('sudah berdaftar bukan SEKATAN - ia keadaan berbeza', () {
      // Ahli yang sudah berdaftar melihat butang "Batal", bukan butang
      // "Daftar" yang dilumpuhkan dengan sebab. Jadi blocker mesti null
      // walaupun canRegister false.
      final a = buatAktiviti(capacity: 10, isRegistered: true);
      expect(a.registrationBlocker, isNull);
      expect(a.canRegister, isFalse);
    });
  });

  group('penghuraian JSON sepadan bentuk backend', () {
    // Bentuk ini disalin daripada apa yang backend BENAR-BENAR hantar:
    // pgtype.Timestamptz marshal jadi rentetan RFC3339Nano, pgtype.Int4
    // jadi nombor atau null. Lihat internal/db/sqlc/activities.sql.go.
    Map<String, dynamic> detailJson() => {
      'id': 'a1',
      'category_id': 'c1',
      'title': 'Kejohanan Badminton',
      'description': 'Perlawanan tahunan',
      'location_name': 'Dewan A',
      'location_address': 'Jalan 1',
      'starts_at': '2026-09-01T09:00:00Z',
      'ends_at': '2026-09-01T12:00:00Z',
      'registration_opens_at': null,
      'registration_closes_at': '2026-08-25T00:00:00Z',
      'capacity': 20,
      'status': 'published',
      'cancelled_reason': null,
      'category_name': 'Badminton',
      'sessions': [
        {
          'id': 's1',
          'seq': 1,
          'title': 'Sesi pagi',
          'starts_at': '2026-09-01T09:00:00Z',
          'ends_at': '2026-09-01T12:00:00Z',
        },
      ],
      'registration_count': 5,
      'is_registered': true,
    };

    test('respons detail dihurai penuh', () {
      final a = Activity.fromJson(detailJson());
      expect(a.title, 'Kejohanan Badminton');
      expect(a.categoryName, 'Badminton');
      expect(a.capacity, 20);
      expect(a.registrationCount, 5);
      expect(a.isRegistered, isTrue);
      expect(a.sessions.single.title, 'Sesi pagi');
      expect(a.slotsLeft, 15);
    });

    test('timestamp ditukar ke waktu tempatan', () {
      final a = Activity.fromJson(detailJson());
      expect(a.startsAt.isUtc, isFalse);
      expect(
        a.startsAt.toUtc(),
        DateTime.utc(2026, 9, 1, 9),
      );
      expect(a.sessions.single.startsAt.isUtc, isFalse);
    });

    test('registration_opens_at dihurai bila ada, null bila tiada', () {
      expect(Activity.fromJson(detailJson()).registrationOpensAt, isNull);

      final json = detailJson()
        ..['registration_opens_at'] = '2026-08-20T00:00:00Z';
      final a = Activity.fromJson(json);
      expect(a.registrationOpensAt!.toUtc(), DateTime.utc(2026, 8, 20));
      expect(a.registrationOpensAt!.isUtc, isFalse);
    });

    test('capacity null dihurai sebagai tiada had', () {
      final json = detailJson()..['capacity'] = null;
      final a = Activity.fromJson(json);
      expect(a.capacity, isNull);
      expect(a.slotsLeft, isNull);
      expect(a.isFull, isFalse);
    });

    test('baris senarai tanpa sessions/is_registered masih sah', () {
      // GET /activities tidak membawa dua medan itu - lalai mesti
      // menampungnya, bukan membaling.
      final json = detailJson()
        ..remove('sessions')
        ..remove('is_registered');
      final a = Activity.fromJson(json);
      expect(a.sessions, isEmpty);
      expect(a.isRegistered, isFalse);
    });
  });
}
