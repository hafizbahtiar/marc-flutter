import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/features/dashboard/dashboard_models.dart';
import 'package:marc/features/profile/profile_providers.dart';

/// Data skrin Utama. SATU panggilan untuk seluruh skrin - lihat spec
/// untuk sebab satu endpoint dipilih berbanding komposisi client-side.
///
/// Memulangkan `null` (bukan melontar) bila ahli belum diluluskan:
/// backend meletakkan `/dashboard` dalam kumpulan `approved`, jadi
/// memanggilnya untuk ahli pending ialah 403 yang boleh diramal 100%.
/// Skrin memapar `PendingStatusView` dalam keadaan itu dan tidak pernah
/// membaca data ini.
final dashboardProvider = FutureProvider<DashboardData?>((ref) async {
  final profile = await ref.watch(myProfileProvider.future);
  if (profile?.status != 'approved') return null;

  final dio = ref.watch(dioProvider);
  final res = await dio.get<Map<String, dynamic>>('/dashboard');
  return DashboardData.fromJson(res.data ?? const {});
});
