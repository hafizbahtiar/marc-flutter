import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/dashboard/dashboard_page.dart';
import 'package:marc/features/dashboard/widgets/member_cards.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/ui/widgets/pending_status_view.dart';

import '../../support/profile_fixtures.dart';

class _LoggedInAuthNotifier extends AuthNotifier {
  _LoggedInAuthNotifier() : super(TokenStorage()) {
    state = const AuthState(isLoggedIn: true, accessToken: 'test-token');
  }
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._onFetch);
  final Future<ResponseBody> Function(RequestOptions options) _onFetch;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _onFetch(options);
}

Dio _dioYangMemulangkan(Map<String, dynamic> body) {
  return Dio()
    ..httpClientAdapter = _FakeAdapter(
      (_) async => ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
}

Dio _dioYangMerekod(List<String> dipanggil) {
  return Dio()
    ..httpClientAdapter = _FakeAdapter((options) async {
      dipanggil.add(options.path);
      return ResponseBody.fromString(
        '{}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
}

Dio _dioYangGagal() {
  return Dio()
    ..httpClientAdapter = _FakeAdapter(
      (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'ujian: rangkaian mati',
      ),
    );
}

Map<String, dynamic> _payloadAhli({
  int certs = 0,
  int members = 0,
  List<Map<String, dynamic>> openActivities = const [],
}) => {
  'member': {
    'membership': {'status': 'approved', 'member_id': 'MARC-001'},
    'open_activities': openActivities,
    'certificates_total': certs,
    'total_members': members,
  },
  'admin': null,
};

Map<String, dynamic> _payloadAdmin({
  int pendingApprovals = 0,
  int? donationCents,
  double? attendanceRate = 0.72,
}) => {
  'member': {
    'membership': {'status': 'approved', 'member_id': 'MARC-001'},
    'open_activities': const [],
    'certificates_total': 12,
    'total_members': 13,
  },
  'admin': {
    'pending_approvals': pendingApprovals,
    'revenue_this_month': {
      'currency': 'myr',
      'registration_cents': 100000,
      'activity_cents': 50000,
      'total_cents': 150000 + (donationCents ?? 0),
      'donation_cents': donationCents,
    },
    'member_stats': {
      'active': 21,
      'pending': 22,
      'new_this_month': 23,
      'by_department': [
        {'code': 'KL', 'name': 'Kuala Lumpur', 'count': 24},
      ],
    },
    'activity_stats': {
      'upcoming': 31,
      'registrations_this_month': 32,
      'attendance_rate': attendanceRate,
    },
  },
};

GoRouter _testRouter() {
  Widget kosong(String label) => Scaffold(body: Text(label));
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
      GoRoute(path: '/notifications', builder: (_, _) => kosong('notifikasi')),
      GoRoute(path: '/my-certificates', builder: (_, _) => kosong('sijil')),
      GoRoute(path: '/members', builder: (_, _) => kosong('ahli')),
      GoRoute(path: '/members/pending', builder: (_, _) => kosong('pending')),
      GoRoute(
        path: '/my-activities',
        builder: (_, _) => kosong('aktiviti-saya'),
      ),
      GoRoute(path: '/activities', builder: (_, _) => kosong('aktiviti')),
      GoRoute(
        path: '/activities/:id',
        builder: (_, state) => kosong('aktiviti-${state.pathParameters['id']}'),
      ),
      GoRoute(path: '/admin/payments', builder: (_, _) => kosong('bayaran')),
      GoRoute(path: '/feed', builder: (_, _) => kosong('feed')),
      GoRoute(path: '/checkout', builder: (_, _) => kosong('checkout')),
    ],
  );
}

Widget _app(Dio dio, GoRouter router, {required Profile profile}) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      authNotifierProvider.overrideWith((ref) => _LoggedInAuthNotifier()),
      myProfileProvider.overrideWith((ref) async => profile),
      routerProvider.overrideWithValue(router),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  testWidgets('ahli pending → PendingStatusView, /dashboard tidak dipanggil', (
    tester,
  ) async {
    final dipanggil = <String>[];
    final dio = _dioYangMerekod(dipanggil);

    await tester.pumpWidget(_app(dio, _testRouter(), profile: pendingProfile));
    await tester.pumpAndSettle();

    expect(find.byType(PendingStatusView), findsOneWidget);
    expect(dipanggil, isEmpty);
  });

  testWidgets('ahli approved tanpa blok admin → tiada kad admin', (
    tester,
  ) async {
    final dio = _dioYangMemulangkan(_payloadAhli());

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    expect(find.text('Aktiviti terbuka'), findsOneWidget);
    expect(find.text('Menunggu kelulusan'), findsNothing);
    expect(find.text('Kutipan bulan ini'), findsNothing);
  });

  // Jalur statistik hero membawa DUA petak sahaja. Notifikasi sengaja
  // TIADA: ia sudah jadi tab bottom-nav dengan lencananya sendiri, jadi
  // petak ketiga cuma mengulangi apa yang sudah dua ketukan jauhnya.
  testWidgets('jalur statistik hero: sijil dan ahli, tiada notifikasi', (
    tester,
  ) async {
    final dio = _dioYangMemulangkan(_payloadAhli(certs: 7, members: 312));

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('Sijil saya'), findsOneWidget);
    expect(find.text('Ahli berdaftar'), findsOneWidget);
    // Tiada petak ketiga. (Bahawa backend LAMA yang masih menghantar
    // `unread_notifications` tidak meranapkan penghuraian diuji di
    // `dashboard_models_test.dart`, bukan di sini - fixture ini sudah
    // tidak membawa medan itu, jadi menegaskan ketiadaannya di sini
    // akan lulus tanpa membuktikan apa-apa.)
    expect(find.text('Notifikasi'), findsNothing);
  });

  testWidgets('hero papar nama ahli dan pil status', (tester) async {
    final dio = _dioYangMemulangkan(_payloadAhli());

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    expect(find.text('Selamat kembali,'), findsOneWidget);
    expect(find.text('Ahli diluluskan'), findsOneWidget);
  });

  // Regresi: versi terdahulu mengapungkan jalur statistik setinggi ~76px
  // pada `bottom: -30`, jadi ia menjulur 46px ke dalam hero sedangkan
  // padding bawah hero cuma 34px - baki 12px menutup nombor ahli.
  // Menegaskan teks "wujud" TIDAK menangkap ini (ia memang wujud, cuma
  // tertutup), jadi ujian ini membandingkan kedudukan sebenar.
  testWidgets('nombor ahli dalam hero tidak bertindih petak di bawahnya', (
    tester,
  ) async {
    final dio = _dioYangMemulangkan(_payloadAhli(certs: 7, members: 312));

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    final bawahNomborAhli = tester.getBottomLeft(find.text('MARC-001')).dy;
    final atasPetakPertama = tester.getTopLeft(find.text('Sijil saya')).dy;

    expect(
      bawahNomborAhli,
      lessThan(atasPetakPertama),
      reason: 'nombor ahli tertutup oleh petak di bawah hero',
    );
  });

  testWidgets('ralat rangkaian → kad "Cuba lagi", skrin tidak kosong', (
    tester,
  ) async {
    final dio = _dioYangGagal();

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    expect(find.text('Cuba lagi'), findsOneWidget);
    // Hero kekal dipapar dalam keadaan ralat - ia identiti, bukan data -
    // jadi pintasan sijil/ahli masih boleh diketuk. Angkanya "—" dan
    // BUKAN "0": sifar ialah kenyataan tentang data, dan ketika ini kita
    // tidak tahu apa-apa.
    expect(find.text('Sijil saya'), findsOneWidget);
    expect(find.text('Ahli berdaftar'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('0'), findsNothing);
  });

  testWidgets('OutstandingFeeCard: butang bayar navigasi ke /checkout', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/kad',
      routes: [
        GoRoute(
          path: '/kad',
          builder: (_, _) =>
              const Scaffold(body: OutstandingFeeCard(feeCents: 5000)),
        ),
        GoRoute(
          path: '/checkout',
          builder: (_, _) => const Scaffold(body: Text('checkout')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MYR 50.00'), findsOneWidget);

    await tester.tap(find.text('Bayar sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('checkout'), findsOneWidget);
  });

  // Kad yuran hanya WUJUD bila ada hutang - ia tidak dipapar kosong -
  // jadi ketiadaannya diuji pada aras halaman, bukan pada kad.
  testWidgets('tiada kad yuran bila outstanding_registration_fee_cents null', (
    tester,
  ) async {
    final dio = _dioYangMemulangkan(_payloadAhli());

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    expect(find.text('Bayar sekarang'), findsNothing);
    expect(find.text('Yuran pendaftaran belum dijelaskan'), findsNothing);
  });

  testWidgets('blok admin terpapar bila admin != null', (tester) async {
    final dio = _dioYangMemulangkan(_payloadAdmin(pendingApprovals: 5));

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    expect(find.text('Menunggu kelulusan'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Kutipan bulan ini'), findsOneWidget);
    expect(find.text('Kuala Lumpur'), findsOneWidget);
  });

  testWidgets('donation_cents null → nota "tidak termasuk derma"', (
    tester,
  ) async {
    final dio = _dioYangMemulangkan(_payloadAdmin(donationCents: null));

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    expect(find.textContaining('tidak termasuk derma'), findsOneWidget);
  });

  testWidgets('donation_cents berisi → tiada nota pengecualian', (
    tester,
  ) async {
    final dio = _dioYangMemulangkan(_payloadAdmin(donationCents: 5000));

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    expect(find.textContaining('tidak termasuk derma'), findsNothing);
  });

  testWidgets('attendance_rate null → papar "—", bukan "0%"', (tester) async {
    final dio = _dioYangMemulangkan(_payloadAdmin(attendanceRate: null));

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    expect(find.text('0%'), findsNothing);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('Menunggu kelulusan: ketukan navigasi ke /members/pending', (
    tester,
  ) async {
    final dio = _dioYangMemulangkan(_payloadAdmin());

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Menunggu kelulusan'));
    await tester.pumpAndSettle();

    expect(find.text('pending'), findsOneWidget);
  });

  testWidgets('Kutipan bulan ini: ketukan navigasi ke /admin/payments', (
    tester,
  ) async {
    final dio = _dioYangMemulangkan(_payloadAdmin());

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kutipan bulan ini'));
    await tester.pumpAndSettle();

    expect(find.text('bayaran'), findsOneWidget);
  });

  testWidgets('Statistik Ahli: ketukan navigasi ke /members', (tester) async {
    final dio = _dioYangMemulangkan(_payloadAdmin());

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Statistik Ahli'));
    await tester.pumpAndSettle();

    expect(find.text('ahli'), findsOneWidget);
  });

  testWidgets('Statistik Aktiviti: ketukan navigasi ke /activities', (
    tester,
  ) async {
    final dio = _dioYangMemulangkan(_payloadAdmin());

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    // Kad ini duduk di hujung senarai, di luar skrin pada saiz ujian -
    // `ListView` hanya melekapkan anak yang kelihatan, jadi tatal dahulu
    // supaya ketukan benar-benar mengena widget dan bukan ruang kosong.
    await tester.scrollUntilVisible(
      find.text('Statistik Aktiviti'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Statistik Aktiviti'));
    await tester.pumpAndSettle();

    expect(find.text('aktiviti'), findsOneWidget);
  });

  // Regresi: `relativeTime()` dikira drpd `DateTime.now().difference(x)`,
  // jadi untuk tarikh AKAN DATANG diff sentiasa negatif, `diff.inSeconds
  // < 60` sentiasa benar, dan setiap aktiviti akan datang papar "baru" -
  // termasuk satu enam bulan lagi. Ujian ni pastikan ia tidak berulang.
  testWidgets('aktiviti jauh di masa depan TIDAK papar "baru"', (tester) async {
    final farFuture = DateTime.now().add(const Duration(days: 180));
    final dio = _dioYangMemulangkan(
      _payloadAhli(
        openActivities: [
          {
            'id': 'act-1',
            'title': 'Bengkel Keselamatan',
            'starts_at': farFuture.toUtc().toIso8601String(),
            'category_name': 'Bengkel',
            'fee_cents': 0,
            'currency': 'myr',
            'registration_count': 3,
          },
        ],
      ),
    );

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    expect(find.text('Bengkel Keselamatan'), findsOneWidget);
    expect(find.textContaining('baru'), findsNothing);
    expect(find.textContaining('hari lagi'), findsOneWidget);
  });

  testWidgets('baris aktiviti terbuka: ketukan navigasi ke /activities/:id', (
    tester,
  ) async {
    final soon = DateTime.now().add(const Duration(days: 5));
    final dio = _dioYangMemulangkan(
      _payloadAhli(
        openActivities: [
          {
            'id': 'act-99',
            'title': 'Seminar Kerjaya',
            'starts_at': soon.toUtc().toIso8601String(),
            'category_name': 'Seminar',
            'fee_cents': 2000,
            'currency': 'myr',
            'registration_count': 12,
          },
        ],
      ),
    );

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    expect(find.text('Seminar Kerjaya'), findsOneWidget);
    expect(find.textContaining('MYR 20.00'), findsOneWidget);
    expect(find.textContaining('12 berdaftar'), findsOneWidget);

    await tester.tap(find.text('Seminar Kerjaya'));
    await tester.pumpAndSettle();

    expect(find.text('aktiviti-act-99'), findsOneWidget);
  });

  testWidgets('yuran tertunggak naik ke atas melebihi blok admin', (
    tester,
  ) async {
    final payload = _payloadAdmin();
    (payload['member'] as Map<String, dynamic>)['membership'] = {
      'status': 'approved',
      'member_id': 'MARC-001',
      'outstanding_registration_fee_cents': 5000,
    };
    final dio = _dioYangMemulangkan(payload);

    await tester.pumpWidget(_app(dio, _testRouter(), profile: approvedProfile));
    await tester.pumpAndSettle();

    final yuranY = tester
        .getTopLeft(find.text('Yuran pendaftaran belum dijelaskan'))
        .dy;
    final adminY = tester.getTopLeft(find.text('Menunggu kelulusan')).dy;
    expect(yuranY, lessThan(adminY));
  });
}
