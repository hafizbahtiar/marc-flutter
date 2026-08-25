import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/features/members/member_detail_model.dart';
import 'package:marc/features/members/member_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';

/// Padan pola `_FakeAdapter` di `test/features/checkout/checkout_providers_test.dart`
/// - duplikasi sengaja (helper test kecil, satu tapak panggilan setiap
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

Dio _dioAlwaysOk() {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = _FakeAdapter(
    (options) async => ResponseBody.fromString(
      jsonEncode(<String, dynamic>{}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    ),
  );
  return dio;
}

MemberDetail _detail() => const MemberDetail(
  userId: 'user-1',
  memberId: 'MARC2026/08/0002',
  displayName: 'Aina',
  avatarUrl: null,
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: 10,
  category: 'ahli',
  status: 'approved',
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
  // Finding 2 (semakan kod bebas): tindakan pengurusan pada
  // MemberDetailPage (tukar status aktif/role/bahagian) mesti invalidate
  // `memberDetailProvider(userId)` sasaran, BUKAN cuma `membersProvider` -
  // kalau tidak header/AppBar skrin detail kekal papar data lapuk selepas
  // tindakan berjaya sehingga pengguna keluar & masuk semula skrin.
  for (final entry in <String, Future<void> Function(ProfileRepository)>{
    'updateMemberActive': (repo) => repo.updateMemberActive('user-1', false),
    'updateMemberRole': (repo) => repo.updateMemberRole('user-1', 'manager'),
    'updateMemberDepartment': (repo) =>
        repo.updateMemberDepartment('user-1', departmentCode: 'ops'),
  }.entries) {
    test(
      '${entry.key} invalidate memberDetailProvider(userId) sasaran',
      () async {
        var fetchCount = 0;
        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(_dioAlwaysOk()),
            memberDetailProvider.overrideWith((ref, userId) async {
              fetchCount++;
              return _detail();
            }),
          ],
        );
        addTearDown(container.dispose);

        // Baca dulu supaya provider "hidup" (ada listener) - invalidate
        // pada provider yang tak pernah dibaca tak boleh diperiksa.
        await container.read(memberDetailProvider('user-1').future);
        expect(fetchCount, 1);

        await entry.value(container.read(profileRepositoryProvider));

        await container.read(memberDetailProvider('user-1').future);
        expect(
          fetchCount,
          2,
          reason:
              '${entry.key} patut invalidate memberDetailProvider("user-1") '
              'supaya skrin detail refetch data terkini',
        );
      },
    );
  }
}
