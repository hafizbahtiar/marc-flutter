import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/admin/blocked_email_domains_models.dart';
import 'package:marc/features/profile/profile_providers.dart';

/// Senarai domain emel disekat - superadmin SAHAJA (padanan gate backend
/// `authz.IsAtLeastRole(..., "superadmin")`). Provider ni sengaja fail
/// senyap (list kosong) kalau bukan superadmin, elak panggilan 403 yang
/// pengguna tak boleh buat apa-apa dengannya - padanan pola
/// `allActivityCategoriesProvider`.
final blockedEmailDomainsProvider = FutureProvider<List<BlockedEmailDomain>>((
  ref,
) async {
  if (!ref.watch(isSuperAdminProvider)) return const [];

  final res = await ref.watch(dioProvider).get('/admin/blocked-email-domains');
  final data = res.data as Map<String, dynamic>;
  return (data['domains'] as List)
      .map((d) => BlockedEmailDomain.fromJson(d as Map<String, dynamic>))
      .toList();
});

/// Hasil satu mutasi (tambah/buang domain).
class BlockedDomainResult {
  const BlockedDomainResult.ok() : message = null;
  const BlockedDomainResult.failed(String this.message);

  final String? message;

  bool get isOk => message == null;
}

final blockedEmailDomainsRepositoryProvider =
    Provider<BlockedEmailDomainsRepository>(
      (ref) => BlockedEmailDomainsRepository(ref),
    );

class BlockedEmailDomainsRepository {
  BlockedEmailDomainsRepository(this._ref);
  final Ref _ref;

  Future<BlockedDomainResult> add(String domain) async {
    try {
      await _ref
          .read(dioProvider)
          .post('/admin/blocked-email-domains', data: {'domain': domain});
      _ref.invalidate(blockedEmailDomainsProvider);
      return const BlockedDomainResult.ok();
    } on DioException catch (e) {
      return BlockedDomainResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const BlockedDomainResult.failed('Gagal tambah domain.');
    }
  }

  /// [domain] dihantar sebagai segmen laluan - Uri.encodeComponent elak
  /// domain dengan aksara istimewa (patut tak pernah berlaku, domain sah
  /// tak ada, tapi jangan pecah URL kalau input pelik terlepas validasi).
  Future<BlockedDomainResult> remove(String domain) async {
    try {
      await _ref
          .read(dioProvider)
          .delete(
            '/admin/blocked-email-domains/${Uri.encodeComponent(domain)}',
          );
      _ref.invalidate(blockedEmailDomainsProvider);
      return const BlockedDomainResult.ok();
    } on DioException catch (e) {
      return BlockedDomainResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const BlockedDomainResult.failed('Gagal buang domain.');
    }
  }
}
