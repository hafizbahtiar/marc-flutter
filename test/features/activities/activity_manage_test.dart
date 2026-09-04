import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/activities/manage/activity_draft.dart';
import 'package:marc/features/activities/manage/manage_providers.dart';

/// Harness sama dengan `activity_registration_test.dart`.
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

Map<String, dynamic> _activityJson({String status = 'published'}) => {
  'id': 'a1',
  'category_id': 'c1',
  'title': 'Kejohanan Badminton',
  'description': '',
  'location_name': 'Dewan A',
  'location_address': '',
  'starts_at': '2099-01-01T09:00:00.000Z',
  'ends_at': '2099-01-01T12:00:00.000Z',
  'registration_closes_at': '2098-12-01T00:00:00.000Z',
  'capacity': 30,
  'registration_count': 5,
  'attendance_threshold_pct': 80,
  'status': status,
  'category_name': 'Sukan',
  'is_registered': false,
  'sessions': const <dynamic>[],
};

Dio _dioWith(Future<ResponseBody> Function(RequestOptions options) onFetch) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = _FakeAdapter(onFetch);
  return dio;
}

ProviderContainer _containerWith(Dio dio) {
  final c = ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(dio),
      authNotifierProvider.overrideWith((ref) => _LoggedInAuthNotifier()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Setiap mutasi memuat semula senarai/detail; ujian di bawah tidak
/// menguji bacaan itu, jadi ia dijawab di satu tempat.
Future<ResponseBody>? _reads(RequestOptions options) {
  if (options.method == 'GET' && options.path == '/activities') {
    return Future.value(
      _jsonResponse({'activities': <dynamic>[], 'next_cursor': null}),
    );
  }
  if (options.method == 'GET' && options.path == '/activities/a1') {
    return Future.value(_jsonResponse(_activityJson()));
  }
  return null;
}

void main() {
  group('PUT sesi', () {
    test(
      '409 → mesej khusus "sudah ada kehadiran", bukan ralat generik',
      () async {
        final dio = _dioWith((options) async {
          final read = _reads(options);
          if (read != null) return read;
          if (options.method == 'PUT' &&
              options.path == '/activities/a1/sessions') {
            // Bentuk sebenar backend - activities.go:1109.
            return _jsonResponse({
              'error': 'sesi yang sudah ada kehadiran tidak boleh diganti',
            }, status: 409);
          }
          throw StateError('Unexpected ${options.method} ${options.path}');
        });

        final result = await _containerWith(dio)
            .read(activityManageRepositoryProvider)
            .replaceSessions('a1', [
              SessionDraft(
                startsAt: DateTime.utc(2099, 1, 1, 1),
                endsAt: DateTime.utc(2099, 1, 1, 4),
              ),
            ]);

        expect(result.isOk, isFalse);
        expect(result.message, sessionsAttendanceConflictMessage);
        expect(result.message, contains('kehadiran'));
        expect(result.message, contains('bukti sijil'));
      },
    );

    test('200 → berjaya', () async {
      final dio = _dioWith((options) async {
        final read = _reads(options);
        if (read != null) return read;
        if (options.method == 'PUT') {
          return _jsonResponse({'sessions': <dynamic>[]});
        }
        throw StateError('Unexpected ${options.method} ${options.path}');
      });

      final result = await _containerWith(dio)
          .read(activityManageRepositoryProvider)
          .replaceSessions('a1', [
            SessionDraft(
              startsAt: DateTime.utc(2099, 1, 1, 1),
              endsAt: DateTime.utc(2099, 1, 1, 4),
            ),
          ]);

      expect(result.isOk, isTrue);
    });
  });

  group('tanda kehadiran', () {
    const path = '/activities/a1/sessions/s1/attendance';

    test(
      '422 → outsideWindow, BUKAN kegagalan biasa (laluan pindaan)',
      () async {
        final dio = _dioWith((options) async {
          if (options.method == 'POST' && options.path == path) {
            return _jsonResponse({
              'error': 'di luar tetingkap check-in',
            }, status: 422);
          }
          throw StateError('Unexpected ${options.method} ${options.path}');
        });

        final result = await _containerWith(dio)
            .read(activityManageRepositoryProvider)
            .markAttendance(
              activityId: 'a1',
              sessionId: 's1',
              registrationId: 'r1',
            );

        expect(result.ok, isFalse);
        expect(result.outsideWindow, isTrue);
        expect(result.message, attendanceOutsideWindowMessage);
      },
    );

    test('pindaan menghantar amend+reason dan diterima', () async {
      Map<String, dynamic>? sent;

      final dio = _dioWith((options) async {
        if (options.method == 'POST' && options.path == path) {
          sent = options.data as Map<String, dynamic>;
          if (sent!['amend'] != true) {
            return _jsonResponse({
              'error': 'di luar tetingkap check-in',
            }, status: 422);
          }
          return _jsonResponse({
            'created': true,
            'member': <String, dynamic>{},
          });
        }
        throw StateError('Unexpected ${options.method} ${options.path}');
      });

      final repo = _containerWith(dio).read(activityManageRepositoryProvider);
      final result = await repo.markAttendance(
        activityId: 'a1',
        sessionId: 's1',
        registrationId: 'r1',
        amendReason: '  lupa scan semasa sesi  ',
      );

      expect(result.ok, isTrue);
      expect(result.created, isTrue);
      expect(sent!['amend'], isTrue);
      expect(sent!['reason'], 'lupa scan semasa sesi');
      expect(sent!['method'], 'manual');
      expect(sent!['registration_id'], 'r1');
    });

    test('sebab pindaan kosong TIDAK pernah dihantar', () async {
      var called = false;
      final dio = _dioWith((options) async {
        called = true;
        throw StateError('permintaan tidak sepatutnya dibuat');
      });

      final result = await _containerWith(dio)
          .read(activityManageRepositoryProvider)
          .markAttendance(
            activityId: 'a1',
            sessionId: 's1',
            registrationId: 'r1',
            amendReason: '   ',
          );

      expect(called, isFalse);
      expect(result.ok, isFalse);
      expect(result.message, 'Sebab pindaan diperlukan.');
    });

    test('422 semasa pindaan tidak mengulang tawaran pindaan lagi', () async {
      final dio = _dioWith((options) async {
        return _jsonResponse({
          'error': 'di luar tetingkap check-in',
        }, status: 422);
      });

      final result = await _containerWith(dio)
          .read(activityManageRepositoryProvider)
          .markAttendance(
            activityId: 'a1',
            sessionId: 's1',
            registrationId: 'r1',
            amendReason: 'pembetulan',
          );

      expect(result.outsideWindow, isFalse);
      expect(result.message, 'di luar tetingkap check-in');
    });

    test('created:false bukan ralat - sudah ditanda hadir', () async {
      final dio = _dioWith((options) async {
        return _jsonResponse({'created': false, 'member': <String, dynamic>{}});
      });

      final result = await _containerWith(dio)
          .read(activityManageRepositoryProvider)
          .markAttendance(
            activityId: 'a1',
            sessionId: 's1',
            registrationId: 'r1',
          );

      expect(result.ok, isTrue);
      expect(result.created, isFalse);
    });

    test('409 (tidak berdaftar) → mesej backend dipapar apa adanya', () async {
      final dio = _dioWith((options) async {
        return _jsonResponse({
          'error': 'ahli ini tidak berdaftar untuk aktiviti ini',
        }, status: 409);
      });

      final result = await _containerWith(dio)
          .read(activityManageRepositoryProvider)
          .markAttendance(
            activityId: 'a1',
            sessionId: 's1',
            registrationId: 'r1',
          );

      expect(result.ok, isFalse);
      expect(result.outsideWindow, isFalse);
      expect(result.message, 'ahli ini tidak berdaftar untuk aktiviti ini');
    });

    test('buang kehadiran: 404 dilayan sebagai berjaya', () async {
      final dio = _dioWith((options) async {
        return _jsonResponse({
          'error': 'kehadiran tidak dijumpai',
        }, status: 404);
      });

      final result = await _containerWith(dio)
          .read(activityManageRepositoryProvider)
          .unmarkAttendance(
            activityId: 'a1',
            sessionId: 's1',
            registrationId: 'r1',
          );

      expect(result.isOk, isTrue);
    });
  });

  group('terbit sijil', () {
    const path = '/activities/a1/certificates';

    test('202 ialah KEJAYAAN separuh jalan dengan kiraan dan arahan '
        'sambung', () async {
      final dio = _dioWith((options) async {
        final read = _reads(options);
        if (read != null) return read;
        if (options.method == 'POST' && options.path == path) {
          return _jsonResponse({
            'issued': 12,
            'files_ready': 7,
            'message':
                'sijil sudah dicipta tetapi sebahagian failnya belum siap; '
                'panggil semula untuk menyambung',
          }, status: 202);
        }
        throw StateError('Unexpected ${options.method} ${options.path}');
      });

      final result = await _containerWith(
        dio,
      ).read(activityManageRepositoryProvider).issueCertificates('a1');

      expect(result.ok, isTrue, reason: '202 bukan ralat');
      expect(result.partial, isTrue);
      expect(result.issued, 12);
      expect(result.filesReady, 7);
      expect(result.message, certificatesPartialMessage);
      expect(result.message, contains('sekali lagi'));
    });

    test('200 → siap sepenuhnya', () async {
      final dio = _dioWith((options) async {
        final read = _reads(options);
        if (read != null) return read;
        return _jsonResponse({
          'issued': 12,
          'files_ready': 12,
          'message': 'sijil siap diterbitkan',
        });
      });

      final result = await _containerWith(
        dio,
      ).read(activityManageRepositoryProvider).issueCertificates('a1');

      expect(result.ok, isTrue);
      expect(result.partial, isFalse);
      expect(result.issued, 12);
      expect(result.filesReady, 12);
    });

    test('422 (aktiviti belum tamat) → gagal dengan sebab backend', () async {
      final dio = _dioWith((options) async {
        final read = _reads(options);
        if (read != null) return read;
        return _jsonResponse({
          'error': 'sijil hanya boleh diterbitkan selepas sesi terakhir tamat',
        }, status: 422);
      });

      final result = await _containerWith(
        dio,
      ).read(activityManageRepositoryProvider).issueCertificates('a1');

      expect(result.ok, isFalse);
      expect(
        result.message,
        'sijil hanya boleh diterbitkan selepas sesi terakhir tamat',
      );
    });

    test('panggilan terbit sijil melanjutkan tempoh menunggu sendiri, '
        'bukan lalai global 12s', () async {
      RequestOptions? sent;

      // Lalai global sebenar (api_client.dart) dicerminkan di sini supaya
      // ujian ini benar-benar membuktikan panggilan itu MENGATASI 12s.
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://test',
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      dio.httpClientAdapter = _FakeAdapter((options) async {
        final read = _reads(options);
        if (read != null) return read;
        sent = options;
        return _jsonResponse({'issued': 0, 'files_ready': 0});
      });

      await _containerWith(
        dio,
      ).read(activityManageRepositoryProvider).issueCertificates('a1');

      expect(sent!.receiveTimeout, certificatesIssueTimeout);
      expect(sent!.sendTimeout, certificatesIssueTimeout);
      expect(
        certificatesIssueTimeout,
        greaterThan(const Duration(seconds: 12)),
        reason: 'lalai global tak cukup untuk kohort besar',
      );
      // Lalai global tidak disentuh.
      expect(dio.options.receiveTimeout, const Duration(seconds: 12));
    });

    test('receiveTimeout dilaporkan sebagai separuh siap boleh sambung, '
        'bukan kegagalan', () async {
      final dio = _dioWith((options) async {
        final read = _reads(options);
        if (read != null) return read;
        throw DioException.receiveTimeout(
          timeout: certificatesIssueTimeout,
          requestOptions: options,
        );
      });

      final result = await _containerWith(
        dio,
      ).read(activityManageRepositoryProvider).issueCertificates('a1');

      expect(result.ok, isTrue, reason: 'server masih bekerja');
      expect(result.partial, isTrue);
      expect(result.countsKnown, isFalse, reason: 'tiada respons dibaca');
      expect(result.message, certificatesTimeoutMessage);
      expect(result.message, contains('sekali lagi'));
    });

    test('ralat sambungan lain kekal kegagalan', () async {
      final dio = _dioWith((options) async {
        final read = _reads(options);
        if (read != null) return read;
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'no route to host',
        );
      });

      final result = await _containerWith(
        dio,
      ).read(activityManageRepositoryProvider).issueCertificates('a1');

      expect(result.ok, isFalse);
    });
  });

  group('PATCH aktiviti', () {
    test('badan yang dihantar ialah diff, bukan objek penuh', () async {
      Map<String, dynamic>? sent;

      final dio = _dioWith((options) async {
        final read = _reads(options);
        if (read != null) return read;
        if (options.method == 'PATCH' && options.path == '/activities/a1') {
          sent = options.data as Map<String, dynamic>;
          return _jsonResponse(_activityJson());
        }
        throw StateError('Unexpected ${options.method} ${options.path}');
      });

      final container = _containerWith(dio);
      final before = ActivityDraft(
        categoryId: 'c1',
        title: 'Kejohanan Badminton',
        locationName: 'Dewan A',
        registrationClosesAt: DateTime.utc(2098, 12),
        capacity: 30,
      );
      final after = before.copy()..capacity = null;

      final result = await container
          .read(activityManageRepositoryProvider)
          .update('a1', buildActivityPatch(before, after));

      expect(result.isOk, isTrue);
      expect(sent, {'capacity': null});
    });
  });

  group('senarai peserta', () {
    test('dihurai dengan medan backend dan disusun ikut nama', () async {
      final dio = _dioWith((options) async {
        if (options.method == 'GET' &&
            options.path == '/activities/a1/registrations') {
          return _jsonResponse({
            'registrations': [
              {
                'id': 'r2',
                'activity_id': 'a1',
                'user_id': 'u2',
                'status': 'registered',
                'payment_status': 'not_required',
                'checkin_token': 'rahsia',
                'registered_at': '2026-08-01T00:00:00Z',
                'member_id': 'MARC-002',
                'display_name': 'Zainal',
                'attended_session_ids': ['s1', 's2'],
              },
              {
                'id': 'r1',
                'activity_id': 'a1',
                'user_id': 'u1',
                'status': 'registered',
                'payment_status': 'not_required',
                'checkin_token': 'rahsia',
                'registered_at': '2026-08-02T00:00:00Z',
                'member_id': 'MARC-001',
                'display_name': null,
                'attended_session_ids': <dynamic>[],
              },
            ],
          });
        }
        throw StateError('Unexpected ${options.method} ${options.path}');
      });

      final rows = await _containerWith(
        dio,
      ).read(activityRegistrantsProvider('a1').future);

      expect(rows.map((r) => r.id), ['r1', 'r2']);
      // Tiada display_name → member_id yang dipapar, bukan rentetan kosong.
      expect(rows.first.name, 'MARC-001');
      expect(rows.last.name, 'Zainal');

      // Kehadiran disemai daripada SATU permintaan - inilah yang
      // membenarkan suis bermula pada keadaan sebenar dan laluan buang
      // kehadiran dicapai untuk silap tanda semalam.
      expect(rows.first.attendedSessionIds, isEmpty);
      expect(rows.first.attended('s1'), isFalse);
      expect(rows.last.attendedSessionIds, ['s1', 's2']);
      expect(rows.last.attended('s2'), isTrue);
    });

    test('medan attended_session_ids yang hilang → senarai kosong, bukan '
        'ranap', () async {
      final dio = _dioWith((options) async {
        return _jsonResponse({
          'registrations': [
            {
              'id': 'r1',
              'activity_id': 'a1',
              'user_id': 'u1',
              'status': 'registered',
              'registered_at': '2026-08-02T00:00:00Z',
              'member_id': 'MARC-001',
              'display_name': 'Ali',
            },
          ],
        });
      });

      final rows = await _containerWith(
        dio,
      ).read(activityRegistrantsProvider('a1').future);

      expect(rows.single.attendedSessionIds, isEmpty);
    });
  });
}
