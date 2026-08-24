import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/activities/manage/registrations_page.dart';
import 'package:marc/features/profile/profile_providers.dart';

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

ResponseBody _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

const _management = Profile(
  memberId: 'MARC-000',
  email: 'pengurus@example.com',
  emailVerified: true,
  status: 'approved',
  displayName: 'Pengurus',
  phone: null,
  roleKey: 'manager',
  roleName: 'Manager',
  roleRank: 3,
  category: 'management',
  telegramLinked: false,
);

Map<String, dynamic> _activityJson() => {
  'id': 'a1',
  'category_id': 'c1',
  'title': 'Kursus Asas',
  'description': '',
  'location_name': 'Dewan A',
  'location_address': '',
  'starts_at': '2026-08-01T01:00:00Z',
  'ends_at': '2026-08-02T04:00:00Z',
  'registration_closes_at': '2026-07-01T00:00:00Z',
  'capacity': null,
  'registration_count': 1,
  'attendance_threshold_pct': 100,
  'status': 'published',
  'category_name': 'Latihan',
  'is_registered': false,
  'sessions': [
    {
      'id': 's1',
      'seq': 1,
      'title': 'Pagi',
      'starts_at': '2026-08-01T01:00:00Z',
      'ends_at': '2026-08-01T04:00:00Z',
    },
    {
      'id': 's2',
      'seq': 2,
      'title': 'Petang',
      'starts_at': '2026-08-02T01:00:00Z',
      'ends_at': '2026-08-02T04:00:00Z',
    },
  ],
};

Map<String, dynamic> _registrationsJson({
  List<String> attended = const [],
}) => {
  'registrations': [
    {
      'id': 'r1',
      'activity_id': 'a1',
      'user_id': 'u1',
      'status': 'registered',
      'registered_at': '2026-07-01T00:00:00Z',
      'member_id': 'MARC-001',
      'display_name': 'Ali',
      'attended_session_ids': attended,
    },
  ],
};

Widget _app(Dio dio) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      authNotifierProvider.overrideWith((ref) => _LoggedInAuthNotifier()),
      myProfileProvider.overrideWith((ref) async => _management),
    ],
    child: const MaterialApp(home: RegistrationsPage(activityId: 'a1')),
  );
}

/// Habiskan kerja async yang tertunda tanpa menjadualkan bingkai.
///
/// Menanda kehadiran membatalkan cache senarai peserta, yang memulakan
/// bacaan semula. Bacaan itu tidak menjadualkan bingkai, jadi
/// `pumpAndSettle` boleh kembali sementara pemasa dio masih tertunggu - dan
/// ujian kemudiannya gagal dengan "A Timer is still pending".
Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Suis bagi peserta tunggal dalam senarai.
bool _switchValue(WidgetTester tester) =>
    tester.widget<Switch>(find.byType(Switch)).value;

/// Buka dropdown sesi dan pilih item yang teksnya mengandungi [label].
///
/// `pumpAndSettle` TIDAK digunakan: semasa permintaan dalam penerbangan,
/// suis digantikan spinner yang beranimasi selamanya, jadi settle tidak
/// akan pernah kembali.
Future<void> _selectSession(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));

  await tester.tap(find.textContaining(label).last);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('suis disemai daripada attended_session_ids server', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.httpClientAdapter = _FakeAdapter((options) async {
      if (options.path == '/activities/a1') {
        return _jsonResponse(_activityJson());
      }
      if (options.path == '/activities/a1/registrations') {
        return _jsonResponse(_registrationsJson(attended: ['s1']));
      }
      throw StateError('Unexpected ${options.method} ${options.path}');
    });

    await tester.pumpWidget(_app(dio));
    await tester.pumpAndSettle();

    // Sesi 1 dipilih automatik, dan Ali memang ditanda hadir untuknya -
    // tanpa menekan apa-apa.
    expect(_switchValue(tester), isTrue);

    // Sesi 2: orang yang sama, kehadiran berbeza.
    await _selectSession(tester, 'Petang');
    expect(_switchValue(tester), isFalse);
  });

  testWidgets(
    'tukar sesi semasa permintaan dalam penerbangan → hasilnya TIDAK '
    'ditulis ke sesi baharu',
    (tester) async {
      // Pintu supaya POST kekal tergantung sementara sesi ditukar.
      final gate = Completer<void>();
      var postSeen = false;

      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.httpClientAdapter = _FakeAdapter((options) async {
        if (options.path == '/activities/a1') {
          return _jsonResponse(_activityJson());
        }
        if (options.path == '/activities/a1/registrations') {
          return _jsonResponse(_registrationsJson());
        }
        if (options.method == 'POST' &&
            options.path == '/activities/a1/sessions/s1/attendance') {
          postSeen = true;
          await gate.future;
          return _jsonResponse({
            'created': true,
            'member': <String, dynamic>{},
          });
        }
        throw StateError('Unexpected ${options.method} ${options.path}');
      });

      await tester.pumpWidget(_app(dio));
      await tester.pumpAndSettle();
      expect(_switchValue(tester), isFalse);

      // Tanda hadir untuk SESI 1 - permintaan tergantung pada pintu.
      await tester.tap(find.byType(Switch));
      // Dipam sehingga permintaan benar-benar bermula; dio melalui
      // beberapa lapisan async sebelum adapter dimasuki.
      for (var i = 0; i < 20 && !postSeen; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(postSeen, isTrue);

      // Tukar ke SESI 2 sementara POST sesi 1 masih dalam penerbangan.
      await _selectSession(tester, 'Petang');

      // Biarkan POST sesi 1 selesai SEKARANG. `pumpAndSettle` selamat di
      // sini: laluan yang dibuang mengosongkan entri busy, jadi tiada
      // spinner yang beranimasi selamanya - dan ia turut menghabiskan
      // bacaan semula senarai yang dicetuskan oleh pembatalan cache.
      gate.complete();
      await tester.pumpAndSettle();
      await _drain(tester);

      // Ali TIDAK hadir untuk sesi 2. Sebelum pembetulan ini, penyelesaian
      // sesi 1 menulis `_marked['r1'] = true` dan sesi 2 memaparkannya
      // sebagai hadir - pembohongan yang kelihatan berwibawa kerana suis
      // yang lain semuanya data sebenar.
      expect(
        _switchValue(tester),
        isFalse,
        reason: 'hasil sesi 1 tidak boleh mendarat dalam paparan sesi 2',
      );

      // Dan spinner tidak tertinggal hidup pada baris itu.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'buka semula skrin selepas menanda → suis ON, bukan cache pra-tanda',
    (tester) async {
      // Cache provider HIDUP LEBIH LAMA daripada skrin (FutureProvider
      // .family bukan autoDispose). Tanpa pembatalan selepas menanda,
      // kemasukan kedua membina State baharu dengan tindihan kosong dan
      // memainkan semula respons LAMA - 30 suis OFF untuk orang yang hadir.
      final attended = <String>[];
      var registrationReads = 0;

      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.httpClientAdapter = _FakeAdapter((options) async {
        if (options.path == '/activities/a1') {
          return _jsonResponse(_activityJson());
        }
        if (options.path == '/activities/a1/registrations') {
          registrationReads++;
          // Server ialah hakim: ia melaporkan apa yang sudah ditanda.
          return _jsonResponse(_registrationsJson(attended: [...attended]));
        }
        if (options.method == 'POST' &&
            options.path == '/activities/a1/sessions/s1/attendance') {
          attended.add('s1');
          return _jsonResponse({
            'created': true,
            'member': <String, dynamic>{},
          });
        }
        throw StateError('Unexpected ${options.method} ${options.path}');
      });

      // ProviderContainer dibina SENDIRI dan dikekalkan merentasi kedua-dua
      // kemasukan. `ProviderScope` biasa tidak memadai: melepaskannya
      // daripada pokok widget MELUPUSKAN containernya, jadi kemasukan kedua
      // akan mendapat cache kosong dan ujian akan lulus walaupun pepijat
      // masih ada. Ini memodelkan app sebenar - satu container seumur hayat
      // app, skrin ditolak dan ditutup di dalamnya.
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          authNotifierProvider.overrideWith((ref) => _LoggedInAuthNotifier()),
          myProfileProvider.overrideWith((ref) async => _management),
        ],
      );
      addTearDown(container.dispose);

      Widget page() => UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RegistrationsPage(activityId: 'a1')),
      );

      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(_switchValue(tester), isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await _drain(tester);
      expect(_switchValue(tester), isTrue);

      // "Tekan kembali": skrin dilupuskan, State (dan tindihannya) hilang.
      // Container - dan cachenya - kekal hidup.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('lain'))),
      );
      await tester.pumpAndSettle();

      // Buka semula.
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await _drain(tester);

      expect(
        _switchValue(tester),
        isTrue,
        reason: 'kemasukan kedua mesti membaca keadaan server yang terkini',
      );
      expect(
        registrationReads,
        greaterThan(1),
        reason: 'senarai dibaca semula selepas tanda, bukan dilayan dari cache',
      );
    },
  );

  testWidgets('kembali ke sesi asal menunjukkan tanda yang berjaya', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.httpClientAdapter = _FakeAdapter((options) async {
      if (options.path == '/activities/a1') {
        return _jsonResponse(_activityJson());
      }
      if (options.path == '/activities/a1/registrations') {
        return _jsonResponse(_registrationsJson());
      }
      if (options.method == 'POST') {
        return _jsonResponse({'created': true, 'member': <String, dynamic>{}});
      }
      throw StateError('Unexpected ${options.method} ${options.path}');
    });

    await tester.pumpWidget(_app(dio));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(_switchValue(tester), isTrue);
  });
}
