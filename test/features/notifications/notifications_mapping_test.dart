import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/notifications/notifications_page.dart';
import 'package:marc/features/posts/post_models.dart';

/// Jenis yang backend benar-benar tulis ke `notifications.type`.
///
/// Sumbernya: handler post/keahlian sedia ada, tambah tiga jenis modul
/// aktiviti (`activities.go`, `activity_certificates.go`). Senarai ini ialah
/// kontrak — ujian di bawah menuntut setiap satunya dipetakan secara
/// eksplisit, jadi jenis server yang baharu akan menjeritkan `assert` di
/// sini dan bukan mewarisi ayat orang lain secara senyap.
/// Sumber kebenaran: kekangan `notifications_type_check` dalam
/// `../marc_go/internal/db/migrations`. Bila migration meluaskan
/// kekangan itu, senarai ni MESTI diluaskan sama — kalau tidak jenis
/// baharu mendarat di `default`, `assert` menembak dalam binaan debug,
/// dan pengguna release nampak ayat neutral.
///
/// Dua terlepas sebelum ni dan ditangkap 2026-08-22: `activity_reminder`
/// (backend 2026-08-15) dan `comment_like` (backend L35, 2026-08-22).
/// Kedua-duanya sudah dipetakan dalam switch; senarai kontrak ni yang
/// ketinggalan.
const _jenisServer = <String>[
  'post_like',
  'comment_like',
  'post_comment',
  'member_pending',
  'member_approved',
  'member_rejected',
  'activity_published',
  'activity_cancelled',
  'activity_reminder',
  'certificate_ready',
];

AppNotification _n(
  String type, {
  String? postId,
  String? activityId,
  String? certificateId,
}) => AppNotification(
  id: 'n1',
  actorId: 'u1',
  type: type,
  postId: postId,
  commentId: null,
  activityId: activityId,
  certificateId: certificateId,
  read: false,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('penghuraian medan deep-link (FIX 2)', () {
    test('activity_id dan certificate_id dihurai daripada JSON', () {
      final n = AppNotification.fromJson({
        'id': 'n1',
        'actor_id': 'u1',
        'type': 'certificate_ready',
        'post_id': null,
        'comment_id': null,
        'activity_id': 'a1',
        'certificate_id': 'c1',
        'read': false,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(n.activityId, 'a1');
      expect(n.certificateId, 'c1');
      expect(n.isCertificateReady, isTrue);
    });

    test('respons lama tanpa medan itu masih dihurai', () {
      final n = AppNotification.fromJson({
        'id': 'n1',
        'actor_id': 'u1',
        'type': 'post_like',
        'post_id': 'p1',
        'comment_id': null,
        'read': true,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(n.activityId, isNull);
      expect(n.certificateId, isNull);
      expect(n.postId, 'p1');
    });

    test('copyWith mengekalkan medan deep-link', () {
      final n = _n('activity_published', activityId: 'a1').copyWith(read: true);
      expect(n.activityId, 'a1');
      expect(n.read, isTrue);
    });
  });

  group('destinasi ketukan (FIX 2)', () {
    test('activity_published → halaman aktiviti', () {
      expect(
        notificationDestination(_n('activity_published', activityId: 'a1')),
        '/activities/a1',
      );
    });

    test('activity_cancelled → halaman aktiviti', () {
      expect(
        notificationDestination(_n('activity_cancelled', activityId: 'a1')),
        '/activities/a1',
      );
    });

    test('certificate_ready membawa KEDUA-DUA id — sijil menang', () {
      expect(
        notificationDestination(
          _n('certificate_ready', activityId: 'a1', certificateId: 'c1'),
        ),
        '/my-certificates',
      );
    });

    test('notifikasi post kekal ke post', () {
      expect(
        notificationDestination(_n('post_like', postId: 'p1')),
        '/posts/p1',
      );
    });

    test('tiada id langsung → tiada destinasi', () {
      expect(notificationDestination(_n('member_pending')), isNull);
    });
  });

  group('pemetaan teks dan ikon (FIX 1)', () {
    test('setiap jenis server dipetakan tanpa assert dan tanpa '
        'mewarisi ayat member_rejected', () {
      final ayatDitolak = notificationTitle(_n('member_rejected'));
      final ikonDitolak = notificationIcon(_n('member_rejected'));

      for (final type in _jenisServer) {
        final title = notificationTitle(_n(type));
        expect(title, isNotEmpty);
        expect(
          title,
          isNot(unknownNotificationTitle),
          reason: '$type tidak dipetakan secara eksplisit',
        );
        if (type != 'member_rejected') {
          expect(
            title,
            isNot(ayatDitolak),
            reason: '$type jatuh ke ayat "tidak diluluskan"',
          );
          expect(
            notificationIcon(_n(type)),
            isNot(ikonDitolak),
            reason: '$type mewarisi ikon batal',
          );
        }
      }
    });

    test('teks aktiviti sepadan dengan suara push server', () {
      expect(notificationTitle(_n('activity_published')), contains('Aktiviti'));
      expect(
        notificationTitle(_n('activity_cancelled')),
        contains('dibatalkan'),
      );
      expect(notificationTitle(_n('certificate_ready')), contains('Sijil'));
    });

    test('jenis yang tidak dikenali menjerit (assert), bukan meminjam '
        'ayat jenis lain', () {
      expect(
        () => notificationTitle(_n('jenis_masa_depan')),
        throwsA(isA<AssertionError>()),
        reason: 'jenis baharu mesti gagal dengan kuat, bukan senyap',
      );
      expect(
        () => notificationIcon(_n('jenis_masa_depan')),
        throwsA(isA<AssertionError>()),
      );
    });

    test('sandaran keluaran ialah ayat neutral', () {
      // Dalam mod keluaran `assert` dibuang; yang tinggal mesti ayat yang
      // tidak menuduh sesiapa apa-apa.
      expect(unknownNotificationTitle, contains('notifikasi'));
      expect(unknownNotificationTitle, isNot(contains('diluluskan')));
    });
  });
}
