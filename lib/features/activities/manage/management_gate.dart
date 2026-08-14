import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/features/activities/manage/manage_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';

/// Menyembunyikan skrin pengurusan daripada ahli biasa.
///
/// KEMUDAHAN UI SAHAJA. Setiap route di belakang skrin ini menyemak
/// `authz.IsManagement` sendiri di backend dan memulangkan 403 — semakan di
/// sini hanya mengelak daripada menunjukkan pintu yang terkunci, dan tidak
/// boleh dipercayai sebagai sempadan keselamatan.
///
/// Profil yang MASIH DIMUAT tidak dilayan sebagai "bukan pengurusan": kalau
/// ia dilayan begitu, skrin akan berkelip "akses ditolak" setiap kali app
/// baru dibuka sebelum `/me` sempat pulang.
///
/// Profil yang GAGAL dimuat juga tidak. `/me` yang 500 atau tumbang kerana
/// talian terputus bukan bukti bahawa orang ini bukan pengurus, dan
/// "Skrin ini untuk pengurusan sahaja" ialah jawapan yang salah DAN jalan
/// mati — ia tidak menawarkan apa-apa untuk dicuba semula.
class ManagementGate extends ConsumerWidget {
  const ManagementGate({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    if (profile.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (profile.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Gagal menyemak kebenaran anda.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.invalidate(myProfileProvider),
                  child: const Text('Cuba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!ref.watch(isManagementProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Skrin ini untuk pengurusan sahaja.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return child;
  }
}
