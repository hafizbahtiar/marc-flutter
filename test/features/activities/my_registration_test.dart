import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/activities/activity_models.dart';

MyRegistration _reg({
  required String id,
  required DateTime startsAt,
  DateTime? endsAt,
  String activityStatus = 'published',
  String checkinToken = 'tok',
}) => MyRegistration(
  id: id,
  activityId: 'a-$id',
  status: 'registered',
  checkinToken: checkinToken,
  registeredAt: DateTime(2026, 1, 1),
  title: 'Aktiviti $id',
  startsAt: startsAt,
  endsAt: endsAt ?? startsAt.add(const Duration(hours: 3)),
  activityStatus: activityStatus,
  categoryName: 'Sukan',
);

void main() {
  final now = DateTime(2026, 8, 13, 12, 0);

  group('MyRegistration.fromJson', () {
    test('menghurai bentuk ListMyRegistrationsRow backend', () {
      final r = MyRegistration.fromJson({
        'id': 'r1',
        'activity_id': 'a1',
        'user_id': 'u1',
        'status': 'registered',
        'payment_status': 'none',
        'payment_ref': null,
        'checkin_token': 'abc123',
        'registered_at': '2026-08-01T02:00:00Z',
        'cancelled_at': null,
        'title': 'Kejohanan Badminton',
        'starts_at': '2026-09-05T01:00:00Z',
        'ends_at': '2026-09-05T04:00:00Z',
        'activity_status': 'published',
        'category_name': 'Sukan',
      });

      expect(r.id, 'r1');
      expect(r.checkinToken, 'abc123');
      expect(r.title, 'Kejohanan Badminton');
      expect(r.startsAt.isUtc, isFalse, reason: 'ditukar ke waktu tempatan');
    });
  });

  group('canCheckInAt', () {
    test('aktiviti akan datang dengan token → QR dipapar', () {
      final r = _reg(id: '1', startsAt: now.add(const Duration(days: 2)));
      expect(r.canCheckInAt(now), isTrue);
    });

    test('aktiviti sedang berjalan → QR masih dipapar', () {
      final r = _reg(
        id: '1',
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: now.add(const Duration(hours: 1)),
      );
      expect(r.isDoneAt(now), isFalse);
      expect(r.canCheckInAt(now), isTrue);
    });

    test('aktiviti sudah tamat → tiada QR', () {
      final r = _reg(id: '1', startsAt: now.subtract(const Duration(days: 2)));
      expect(r.isDoneAt(now), isTrue);
      expect(r.canCheckInAt(now), isFalse);
    });

    test('ditanda completed lebih awal daripada ends_at → tiada QR', () {
      // Pengurusan boleh menutup aktiviti sebelum jam tamat; check-in
      // ditutup bersamanya.
      final r = _reg(
        id: '1',
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: now.add(const Duration(hours: 5)),
        activityStatus: 'completed',
      );
      expect(r.canCheckInAt(now), isFalse);
    });

    test('aktiviti dibatalkan → tiada QR', () {
      final r = _reg(
        id: '1',
        startsAt: now.add(const Duration(days: 2)),
        activityStatus: 'cancelled',
      );
      expect(r.isCancelled, isTrue);
      expect(r.canCheckInAt(now), isFalse);
    });

    test('token kosong → tiada QR (bukan QR kosong yang tak boleh '
        'diimbas)', () {
      final r = _reg(
        id: '1',
        startsAt: now.add(const Duration(days: 2)),
        checkinToken: '',
      );
      expect(r.canCheckInAt(now), isFalse);
    });
  });

  group('groupRegistrations', () {
    test('akan datang menaik, lepas menurun', () {
      // Backend hantar starts_at DESC; yang akan datang mesti dibalik.
      final rows = [
        _reg(id: 'jauh', startsAt: now.add(const Duration(days: 30))),
        _reg(id: 'hampir', startsAt: now.add(const Duration(days: 1))),
        _reg(id: 'semalam', startsAt: now.subtract(const Duration(days: 1))),
        _reg(id: 'lama', startsAt: now.subtract(const Duration(days: 60))),
      ];

      final g = groupRegistrations(rows, now: now);

      expect(g.upcoming.map((r) => r.id), ['hampir', 'jauh']);
      expect(g.past.map((r) => r.id), ['semalam', 'lama']);
      expect(g.isEmpty, isFalse);
    });

    test('aktiviti dibatalkan yang belum tamat kekal dalam Akan Datang', () {
      final rows = [
        _reg(
          id: 'batal',
          startsAt: now.add(const Duration(days: 3)),
          activityStatus: 'cancelled',
        ),
      ];

      final g = groupRegistrations(rows, now: now);

      expect(g.upcoming.single.id, 'batal');
      expect(g.past, isEmpty);
    });

    test('senarai kosong', () {
      final g = groupRegistrations(const [], now: now);
      expect(g.isEmpty, isTrue);
    });
  });
}
