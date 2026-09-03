import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/members/member_detail_model.dart';
import 'package:marc/features/members/member_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';

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

Dio _dioWith(Future<ResponseBody> Function(RequestOptions options) onFetch) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = _FakeAdapter(onFetch);
  return dio;
}

ResponseBody _json(Map<String, dynamic> body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

MemberDetail _detail() => const MemberDetail(
  userId: 'user-1',
  memberId: null,
  displayName: 'Aina',
  avatarUrl: null,
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: 10,
  category: 'ahli',
  status: 'pending',
  isActive: true,
  departmentCode: null,
  departmentName: null,
  position: null,
  email: null,
  phone: null,
  registrationPaymentStatus: null,
  emergencyContactName: null,
  emergencyContactPhone: null,
  healthNotes: null,
  telegramLinked: null,
  telegramUsername: null,
  addresses: null,
);

void main() {
  group('ProfileRepository.verifyStaffID', () {
    test('POST /members/:id/verify-staff-id tanpa body', () async {
      String? method;
      String? path;
      Object? data;
      final dio = _dioWith((options) async {
        method = options.method;
        path = options.path;
        data = options.data;
        return _json({'member_id': 'MARC2026/09/0001'});
      });
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      await container.read(profileRepositoryProvider).verifyStaffID('user-1');

      expect(method, 'POST');
      expect(path, '/members/user-1/verify-staff-id');
      expect(data, isNull);
    });

    test('hantar staff_id override bila diberi', () async {
      Object? data;
      final dio = _dioWith((options) async {
        data = options.data;
        return _json({'member_id': 'MARC2026/09/0001'});
      });
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      await container
          .read(profileRepositoryProvider)
          .verifyStaffID('user-1', staffId: 'EMP-001');

      expect(data, {'staff_id': 'EMP-001'});
    });

    test('403/409/404 petik mesej backend', () async {
      for (final entry in {
        403: 'tidak dibenarkan',
        409: 'ahli ni dah ditolak',
        404: 'ahli tidak dijumpai',
      }.entries) {
        final dio = _dioWith(
          (options) async => _json({'error': entry.value}, status: entry.key),
        );
        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(dio)],
        );
        addTearDown(container.dispose);

        try {
          await container.read(profileRepositoryProvider).verifyStaffID('u');
          fail('expected DioException for ${entry.key}');
        } on DioException catch (e) {
          expect(extractErrorMessage(e), entry.value);
        }
      }
    });

    test('invalidate pendingMembersProvider + memberDetailProvider', () async {
      var pendingFetches = 0;
      var detailFetches = 0;
      final dio = _dioWith((options) async => _json({}));
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          pendingMembersProvider.overrideWith((ref) async {
            pendingFetches++;
            return const [];
          }),
          memberDetailProvider.overrideWith((ref, userId) async {
            detailFetches++;
            return _detail();
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(pendingMembersProvider.future);
      await container.read(memberDetailProvider('user-1').future);
      expect(pendingFetches, 1);
      expect(detailFetches, 1);

      await container.read(profileRepositoryProvider).verifyStaffID('user-1');

      await container.read(pendingMembersProvider.future);
      await container.read(memberDetailProvider('user-1').future);
      expect(pendingFetches, 2);
      expect(detailFetches, 2);
    });
  });

  group('ProfileRepository.correctStaffID', () {
    test('PATCH /members/:id/staff-id dengan body', () async {
      String? method;
      String? path;
      Object? data;
      final dio = _dioWith((options) async {
        method = options.method;
        path = options.path;
        data = options.data;
        return _json({'staff_id': 'EMP-REAL-001'});
      });
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      await container
          .read(profileRepositoryProvider)
          .correctStaffID('user-1', 'EMP-REAL-001');

      expect(method, 'PATCH');
      expect(path, '/members/user-1/staff-id');
      expect(data, {'staff_id': 'EMP-REAL-001'});
    });

    test('403/409/404 petik mesej backend', () async {
      for (final entry in {
        403: 'tidak dibenarkan',
        409: 'nombor staff ini sudah digunakan',
        404: 'ahli tidak dijumpai',
      }.entries) {
        final dio = _dioWith(
          (options) async => _json({'error': entry.value}, status: entry.key),
        );
        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(dio)],
        );
        addTearDown(container.dispose);

        try {
          await container
              .read(profileRepositoryProvider)
              .correctStaffID('u', 'EMP-1');
          fail('expected DioException for ${entry.key}');
        } on DioException catch (e) {
          expect(extractErrorMessage(e), entry.value);
        }
      }
    });
  });
}
