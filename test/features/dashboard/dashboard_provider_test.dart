import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/features/dashboard/dashboard_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';

import '../../support/profile_fixtures.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<String> paths = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return ResponseBody.fromString(
      jsonEncode({
        'member': {
          'membership': {'status': 'approved'},
          'total_members': 7,
        },
        'admin': null,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('ahli approved → /dashboard dipanggil', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        myProfileProvider.overrideWith((ref) async => approvedProfile),
      ],
    );
    addTearDown(container.dispose);

    final data = await container.read(dashboardProvider.future);

    expect(adapter.paths, ['/dashboard']);
    expect(data!.member.totalMembers, 7);
  });

  test('ahli pending → TIADA panggilan rangkaian, data null', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        myProfileProvider.overrideWith((ref) async => pendingProfile),
      ],
    );
    addTearDown(container.dispose);

    final data = await container.read(dashboardProvider.future);

    expect(adapter.paths, isEmpty, reason: '403 yang boleh diramal tidak patut dipanggil');
    expect(data, isNull);
  });
}
