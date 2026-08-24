import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/activities/activity_providers.dart';

/// Corak harness sama dengan `feed_notifier_test.dart`.
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

Map<String, dynamic> _activityJson({
  int registrationCount = 5,
  int? capacity = 10,
  bool isRegistered = false,
}) => {
  'id': 'a1',
  'category_id': 'c1',
  'title': 'Kejohanan Badminton',
  'description': '',
  'location_name': 'Dewan A',
  'location_address': '',
  'starts_at': '2099-01-01T09:00:00.000Z',
  'ends_at': '2099-01-01T12:00:00.000Z',
  'registration_closes_at': '2098-12-01T00:00:00.000Z',
  'capacity': capacity,
  'registration_count': registrationCount,
  'status': 'published',
  'category_name': 'Sukan',
  'is_registered': isRegistered,
};

Dio _dioWith(Future<ResponseBody> Function(RequestOptions options) onFetch) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = _FakeAdapter(onFetch);
  return dio;
}

/// Pusing baris gilir microtask sehingga [check] benar - segerak dengan
/// permintaan yang baru bermula tanpa bergantung pada masa jam sebenar.
Future<void> _waitUntil(bool Function() check) async {
  while (!check()) {
    await Future<void>.delayed(Duration.zero);
  }
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

void main() {
  test('daftar berjaya → kiraan senarai naik dan diselaraskan dgn server',
      () async {
    var registered = false;

    final dio = _dioWith((options) async {
      if (options.method == 'GET' && options.path == '/activities') {
        return _jsonResponse({
          'activities': [_activityJson()],
          'next_cursor': null,
        });
      }
      if (options.method == 'POST' &&
          options.path == '/activities/a1/registration') {
        registered = true;
        return _jsonResponse({'registration': <String, dynamic>{}}, status: 201);
      }
      if (options.method == 'GET' && options.path == '/activities/a1') {
        // Server ialah hakim: ia melaporkan 6 kerana pendaftaran kita
        // mendarat.
        return _jsonResponse(
          _activityJson(registrationCount: 6, isRegistered: true),
        );
      }
      if (options.method == 'GET' && options.path == '/me/activities') {
        return _jsonResponse({'registrations': <dynamic>[]});
      }
      throw StateError('Unexpected ${options.method} ${options.path}');
    });

    final container = _containerWith(dio);
    await container.read(activitiesProvider.future);

    final result = await container
        .read(activityRepositoryProvider)
        .register('a1');

    expect(result.isOk, isTrue);
    expect(registered, isTrue);
    final row = container.read(activitiesProvider).value!.activities.single;
    expect(row.registrationCount, 6);
    expect(row.isRegistered, isTrue);
  });

  test('409 dari server → kiraan optimistik digulung semula dan mesej '
      'Bahasa Melayu dipulangkan', () async {
    // Pintu supaya kita boleh MEMERHATI keadaan optimistik di tengah
    // penerbangan. Tanpa ini, hanya keadaan akhir yang diuji - dan
    // keadaan akhir yang betul juga akan berlaku kalau kemas kini
    // optimistik itu dipadam terus, jadi ujian tidak akan memagar apa-apa.
    final gate = Completer<void>();
    var registerRequested = false;

    final dio = _dioWith((options) async {
      if (options.method == 'GET' && options.path == '/activities') {
        return _jsonResponse({
          'activities': [_activityJson(registrationCount: 9, capacity: 10)],
          'next_cursor': null,
        });
      }
      if (options.method == 'POST' &&
          options.path == '/activities/a1/registration') {
        registerRequested = true;
        await gate.future;
        // Bentuk sebenar yang backend hantar - lihat
        // internal/http/handlers/activity_registrations.go:170.
        return _jsonResponse({'error': 'aktiviti sudah penuh'}, status: 409);
      }
      if (options.method == 'GET' && options.path == '/activities/a1') {
        return _jsonResponse(_activityJson(registrationCount: 9, capacity: 10));
      }
      throw StateError('Unexpected ${options.method} ${options.path}');
    });

    final container = _containerWith(dio);
    await container.read(activitiesProvider.future);
    expect(
      container.read(activitiesProvider).value!.activities.single
          .registrationCount,
      9,
    );

    final pending = container.read(activityRepositoryProvider).register('a1');
    await _waitUntil(() => registerRequested);

    // DI TENGAH PENERBANGAN: kemas kini optimistik mesti kelihatan.
    final midFlight = container
        .read(activitiesProvider)
        .value!
        .activities
        .single;
    expect(midFlight.registrationCount, 10, reason: 'kiraan optimistik +1');
    expect(midFlight.isRegistered, isTrue);

    gate.complete();
    final result = await pending;

    expect(result.isOk, isFalse);
    expect(result.message, 'aktiviti sudah penuh');

    // Digulung semula ke pra-imej: 9, bukan 10 yang optimistik.
    final row = container.read(activitiesProvider).value!.activities.single;
    expect(row.registrationCount, 9);
    expect(row.isRegistered, isFalse);
  });

  test('batal pendaftaran menurunkan kiraan', () async {
    final dio = _dioWith((options) async {
      if (options.method == 'GET' && options.path == '/activities') {
        return _jsonResponse({
          'activities': [_activityJson(registrationCount: 6, isRegistered: true)],
          'next_cursor': null,
        });
      }
      if (options.method == 'DELETE' &&
          options.path == '/activities/a1/registration') {
        return _jsonResponse({'registration': <String, dynamic>{}});
      }
      if (options.method == 'GET' && options.path == '/activities/a1') {
        return _jsonResponse(_activityJson(registrationCount: 5));
      }
      if (options.method == 'GET' && options.path == '/me/activities') {
        return _jsonResponse({'registrations': <dynamic>[]});
      }
      throw StateError('Unexpected ${options.method} ${options.path}');
    });

    final container = _containerWith(dio);
    await container.read(activitiesProvider.future);

    final result = await container
        .read(activityRepositoryProvider)
        .cancel('a1');

    expect(result.isOk, isTrue);
    final row = container.read(activitiesProvider).value!.activities.single;
    expect(row.registrationCount, 5);
    expect(row.isRegistered, isFalse);
  });
}
