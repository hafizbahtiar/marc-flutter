import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/activities/manage/manage_providers.dart';
import 'package:marc/features/admin/departments_models.dart';
import 'package:marc/features/profile/profile_providers.dart';

/// Senarai bahagian/jabatan - superadmin SAHAJA, padanan pola
/// `blockedEmailDomainsProvider` (fail senyap kalau bukan superadmin).
/// Utk skrin CRUD (`DepartmentsPage`) SAHAJA - guna
/// [assignableDepartmentsProvider] utk pemilih bahagian ahli.
final departmentsProvider = FutureProvider<List<Department>>((ref) async {
  if (!ref.watch(isSuperAdminProvider)) return const [];

  final res = await ref.watch(dioProvider).get('/admin/departments');
  final data = res.data as Map<String, dynamic>;
  return (data['departments'] as List)
      .map((d) => Department.fromJson(d as Map<String, dynamic>))
      .toList();
});

/// Senarai bahagian/jabatan (baca sahaja) - manager KE ATAS, padanan gate
/// backend `GET /departments` (`ListForAssignment`). Guna ni utk pemilih
/// bahagian bila tetapkan bahagian/jawatan seorang ahli - BUKAN
/// [departmentsProvider] (superadmin sahaja, skrin CRUD).
final assignableDepartmentsProvider = FutureProvider<List<Department>>((
  ref,
) async {
  if (!ref.watch(isManagerOrAboveProvider)) return const [];

  final res = await ref.watch(dioProvider).get('/departments');
  final data = res.data as Map<String, dynamic>;
  return (data['departments'] as List)
      .map((d) => Department.fromJson(d as Map<String, dynamic>))
      .toList();
});

/// Hasil satu mutasi (tambah/kemas kini/buang bahagian).
class DepartmentResult {
  const DepartmentResult.ok() : message = null;
  const DepartmentResult.failed(String this.message);

  final String? message;

  bool get isOk => message == null;
}

final departmentsRepositoryProvider = Provider<DepartmentsRepository>(
  (ref) => DepartmentsRepository(ref),
);

class DepartmentsRepository {
  DepartmentsRepository(this._ref);
  final Ref _ref;

  Future<DepartmentResult> add({
    required String code,
    required String name,
    int sortOrder = 0,
  }) async {
    try {
      await _ref
          .read(dioProvider)
          .post(
            '/admin/departments',
            data: {'code': code, 'name': name, 'sort_order': sortOrder},
          );
      _ref.invalidate(departmentsProvider);
      return const DepartmentResult.ok();
    } on DioException catch (e) {
      return DepartmentResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const DepartmentResult.failed('Gagal tambah bahagian.');
    }
  }

  Future<DepartmentResult> update(String code, {required String name}) async {
    try {
      await _ref
          .read(dioProvider)
          .patch(
            '/admin/departments/${Uri.encodeComponent(code)}',
            data: {'name': name},
          );
      _ref.invalidate(departmentsProvider);
      return const DepartmentResult.ok();
    } on DioException catch (e) {
      return DepartmentResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const DepartmentResult.failed('Gagal kemas kini bahagian.');
    }
  }

  Future<DepartmentResult> remove(String code) async {
    try {
      await _ref
          .read(dioProvider)
          .delete('/admin/departments/${Uri.encodeComponent(code)}');
      _ref.invalidate(departmentsProvider);
      return const DepartmentResult.ok();
    } on DioException catch (e) {
      return DepartmentResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const DepartmentResult.failed('Gagal buang bahagian.');
    }
  }
}
