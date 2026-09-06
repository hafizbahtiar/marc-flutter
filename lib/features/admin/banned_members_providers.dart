import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/admin/banned_members_models.dart';
import 'package:marc/features/profile/profile_providers.dart';

final bannedMembersProvider = FutureProvider<List<BannedMember>>((ref) async {
  if (!ref.watch(isSuperAdminProvider)) return const [];
  final response = await ref.watch(dioProvider).get('/admin/banned-members');
  final data = response.data as Map<String, dynamic>;
  final rows = data['members'] as List? ?? const [];
  return rows
      .map((row) => BannedMember.fromJson(row as Map<String, dynamic>))
      .toList();
});

class BannedMembersRepository {
  BannedMembersRepository(this._ref);
  final Ref _ref;

  Future<String?> unban(String userId) async {
    try {
      await _ref
          .read(dioProvider)
          .delete('/admin/members/${Uri.encodeComponent(userId)}/ban');
      _ref.invalidate(bannedMembersProvider);
      return null;
    } on DioException catch (e) {
      return extractErrorMessage(e);
    } catch (_) {
      return 'Gagal membuka penggantungan akaun.';
    }
  }

  Future<String?> ban({
    required String userId,
    required String reason,
    DateTime? expiresAt,
  }) async {
    try {
      await _ref
          .read(dioProvider)
          .post(
            '/admin/members/${Uri.encodeComponent(userId)}/ban',
            data: {
              'reason': reason,
              if (expiresAt != null)
                'expires_at': expiresAt.toUtc().toIso8601String(),
            },
          );
      _ref.invalidate(bannedMembersProvider);
      return null;
    } on DioException catch (e) {
      return extractErrorMessage(e);
    } catch (_) {
      return 'Gagal menggantung akaun.';
    }
  }
}

final bannedMembersRepositoryProvider = Provider<BannedMembersRepository>(
  (ref) => BannedMembersRepository(ref),
);
