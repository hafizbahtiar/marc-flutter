import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/features/checkout/checkout_providers.dart';

/// Padan pola `_FakeAdapter` di `test/features/posts/feed_notifier_test.dart`
/// — duplikasi sengaja (helper test kecil, satu tapak panggilan setiap
/// fail), bukan diekstrak jadi kebergantungan silang-fail.
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
  ) {
    return _onFetch(options);
  }
}

Dio _dioWith(Future<ResponseBody> Function(RequestOptions options) onFetch) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = _FakeAdapter(onFetch);
  return dio;
}

void main() {
  test('respons sah pulang gateway_charge_cents daripada backend', () async {
    final dio = _dioWith(
      (options) async => ResponseBody.fromString(
        jsonEncode({'gateway_charge_cents': 250}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);

    final result = await container.read(paymentConfigProvider.future);
    expect(result, 250);
  });

  test('medan gateway_charge_cents tiada — fallback kDefaultGatewayChargeCents', () async {
    final dio = _dioWith(
      (options) async => ResponseBody.fromString(
        jsonEncode(<String, dynamic>{}), // medan tiada dalam respons
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);

    final result = await container.read(paymentConfigProvider.future);
    expect(result, kDefaultGatewayChargeCents);
  });

  test('ralat network — fallback kDefaultGatewayChargeCents, tak throw', () async {
    final dio = _dioWith((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);

    final result = await container.read(paymentConfigProvider.future);
    expect(result, kDefaultGatewayChargeCents);
  });

  test('backend lama (404, route tiada) — fallback kDefaultGatewayChargeCents', () async {
    final dio = _dioWith(
      (options) async => ResponseBody.fromString(
        jsonEncode({'error': 'not found'}),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);

    final result = await container.read(paymentConfigProvider.future);
    expect(result, kDefaultGatewayChargeCents);
  });
}
