import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/features/members/member_detail_model.dart';

/// Profil SATU ahli (skrin `MemberDetailPage`, `GET /members/:id`) - BUKAN
/// `myProfileProvider` (`/me`). Reaktif pada status log masuk, sama
/// rasional dengan `postDetailProvider` (`post_providers.dart`) - throw
/// bila logout supaya `MemberDetailPage` papar error state sedia ada dan
/// bukan cache profil ahli lama. Route ni sepatutnya tak boleh dicapai
/// selepas logout pun (GoRouter redirect ke /login), jadi ini
/// defence-in-depth untuk senario sama-peranti/timing edge case.
final memberDetailProvider = FutureProvider.family<MemberDetail, String>((
  ref,
  userId,
) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) {
    throw StateError('Sesi tamat - sila log masuk semula.');
  }

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/members/$userId');
  return MemberDetail.fromJson(res.data as Map<String, dynamic>);
});
