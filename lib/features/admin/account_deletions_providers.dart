import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/admin/account_deletions_models.dart';
import 'package:marc/features/profile/profile_providers.dart';

class AccountDeletionData {
  const AccountDeletionData({required this.requests, required this.targets});

  final List<AccountDeletionRow> requests;
  final List<AccountDeletionRow> targets;
}

final accountDeletionProvider = FutureProvider<AccountDeletionData>((
  ref,
) async {
  if (!ref.watch(isSuperAdminProvider)) {
    return const AccountDeletionData(requests: [], targets: []);
  }
  final dio = ref.watch(dioProvider);
  final responses = await Future.wait([
    dio.get('/admin/account-deletion-requests'),
    dio.get('/admin/account-deletion-targets'),
  ]);
  List<AccountDeletionRow> parse(Response<dynamic> response) {
    final data = response.data as Map<String, dynamic>;
    final rows =
        data.values.firstWhere(
              (value) => value is List,
              orElse: () => const <dynamic>[],
            )
            as List;
    return rows
        .map((row) => AccountDeletionRow.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  return AccountDeletionData(
    requests: parse(responses[0]),
    targets: parse(responses[1]),
  );
});

class AccountDeletionRepository {
  AccountDeletionRepository(this._ref);
  final Ref _ref;

  Future<String?> executeRequest(String userId) async {
    try {
      await _ref
          .read(dioProvider)
          .post(
            '/admin/account-deletion-requests/${Uri.encodeComponent(userId)}/execute',
          );
      _ref.invalidate(accountDeletionProvider);
      return null;
    } on DioException catch (e) {
      return extractErrorMessage(e);
    } catch (_) {
      return 'Gagal memproses permintaan pemadaman.';
    }
  }

  Future<String?> executeDirect(String userId, String reason) async {
    try {
      await _ref
          .read(dioProvider)
          .post(
            '/admin/account-deletion-targets/${Uri.encodeComponent(userId)}/execute',
            data: {'reason': reason},
          );
      _ref.invalidate(accountDeletionProvider);
      return null;
    } on DioException catch (e) {
      return extractErrorMessage(e);
    } catch (_) {
      return 'Gagal memadam akaun.';
    }
  }
}

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>(
  (ref) => AccountDeletionRepository(ref),
);
