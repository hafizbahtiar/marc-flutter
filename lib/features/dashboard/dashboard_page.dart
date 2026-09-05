import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/features/dashboard/dashboard_providers.dart';
import 'package:marc/features/dashboard/widgets/admin_section.dart';
import 'package:marc/features/dashboard/widgets/dashboard_hero.dart';
import 'package:marc/features/dashboard/widgets/member_cards.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/ui/widgets/email_not_verified_view.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';
import 'package:marc/shared/ui/widgets/pending_status_view.dart';

/// Skrin Utama app. Gate pending/emel di sini MENYALIN corak
/// feed_page.dart:58-140 dengan sengaja: Dashboard kini destinasi lalai
/// selepas log masuk, jadi ia mewarisi tanggungjawab Feed sebagai skrin
/// pertama yang dilihat ahli BELUM diluluskan.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sama seperti feed_page.dart:73-97 - .select dengan record supaya
    // widget ni hanya rebuild bila salah satu lima medan ni berubah.
    final (
      status: profileStatus,
      emailVerified: profileEmailVerified,
      registrationPaymentStatus: profileRegistrationPaymentStatus,
      registrationFeeCents: profileRegistrationFeeCents,
      displayName: profileDisplayName,
      isInitialLoading: profileIsInitialLoading,
    ) = ref.watch(
      myProfileProvider.select(
        (p) => (
          status: p.valueOrNull?.status,
          emailVerified: p.valueOrNull?.emailVerified,
          registrationPaymentStatus: p.valueOrNull?.registrationPaymentStatus,
          registrationFeeCents: p.valueOrNull?.registrationFeeCents,
          displayName: p.valueOrNull?.displayName,
          // Muat pertama (belum PERNAH ada nilai) - beza dgn `hasError`
          // (rangkaian gagal SELEPAS cubaan pertama), yang kekal
          // fail-open sengaja. Tanpa semakan ni, `status` null semasa
          // loading pertama sama macam null semasa error - gate di bawah
          // gagal terbuka, Dashboard penuh terpapar sekejap sebelum
          // status sebenar ahli diketahui (bug sebenar 2026-08-24 pada
          // Feed).
          isInitialLoading: p.isLoading && !p.hasValue,
        ),
      ),
    );

    if (profileIsInitialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (profileStatus != null && profileStatus != 'approved') {
      return PendingStatusView(
        status: profileStatus,
        registrationPaymentStatus: profileRegistrationPaymentStatus,
        registrationFeeCents: profileRegistrationFeeCents,
        onRefresh: () async {
          try {
            final refreshed = await ref.refresh(myProfileProvider.future);
            if (refreshed?.status == 'approved') {
              ref.invalidate(dashboardProvider);
            }
          } catch (_) {
            if (context.mounted) {
              MySnackBar.error(context, 'Gagal semak status. Cuba lagi.');
            }
          }
        },
      );
    }

    if (profileStatus == 'approved' && profileEmailVerified == false) {
      return EmailNotVerifiedView(
        onRefresh: () async {
          try {
            final _ = await ref.refresh(myProfileProvider.future);
          } catch (_) {
            if (context.mounted) {
              MySnackBar.error(context, 'Gagal semak status. Cuba lagi.');
            }
          }
        },
      );
    }

    final dashboard = ref.watch(dashboardProvider);

    // TIADA `AppBar`: salam dan nama ahli hidup dalam jalur hero, dan
    // app bar kosong di atasnya cuma akan memotong jalur itu daripada
    // bahagian atas skrin. `DashboardHero` menempah sendiri ruang status
    // bar melalui `MediaQuery.paddingOf(context).top`.
    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          await ref.read(dashboardProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: dashboard.when(
            // Hero dipapar dalam KETIGA-TIGA keadaan - ia identiti, bukan
            // data. Yang berubah cuma sama ada angka dan pil status ada.
            loading: () => [
              DashboardHero(displayName: profileDisplayName),
              const SizedBox(height: 16),
              const _SkeletonBlock(height: 92),
              const _SkeletonBlock(height: 120),
            ],
            error: (_, _) => [
              DashboardHero(displayName: profileDisplayName),
              const SizedBox(height: 16),
              // Petak kekal boleh diketuk walaupun tanpa data - pintasan
              // sijil/ahli masih berguna, dan angkanya "—" bukan "0".
              const MemberStatsBento(
                certificatesTotal: null,
                totalMembers: null,
              ),
              _ErrorCard(onRetry: () => ref.invalidate(dashboardProvider)),
            ],
            data: (data) {
              // `dashboardProvider` menghasilkan `DashboardData?`. Null di
              // sini bermakna "ahli belum diluluskan" - keadaan yang gate
              // di atas sudah tangkap, jadi cabang ni tidak boleh dicapai.
              // TIDAK guna `!`: gate dan provider ialah dua semakan
              // berasingan, dan `!` di sini akan jadi crash kalau salah
              // satu daripadanya berubah kemudian.
              if (data == null) {
                return [DashboardHero(displayName: profileDisplayName)];
              }

              final outstanding = data.member.membership.outstandingFeeCents;

              return [
                DashboardHero(
                  displayName: profileDisplayName,
                  membership: data.member.membership,
                ),
                // Yuran tertunggak mendahului SEMUANYA, termasuk blok
                // admin: ahli yang berhutang tidak sepatutnya perlu tatal
                // melepasi statistik orang lain untuk nampak sebabnya.
                if (outstanding != null)
                  OutstandingFeeCard(feeCents: outstanding),
                const SizedBox(height: 16),
                MemberStatsBento(
                  certificatesTotal: data.member.certificatesTotal,
                  totalMembers: data.member.totalMembers,
                ),
                if (data.admin != null) ...[
                  const DashboardSectionHeading(title: 'Perlu perhatian'),
                  AdminSection(admin: data.admin!),
                ],
                DashboardSectionHeading(
                  title: 'Aktiviti terbuka',
                  actionLabel: 'Lihat semua',
                  onAction: () => context.push('/activities'),
                ),
                OpenActivitiesList(activities: data.member.openActivities),
              ];
            },
          ),
        ),
      ),
    );
  }
}

/// Blok kelabu berbentuk kandungan sebenar semasa memuat - bukan spinner
/// tengah skrin, supaya bentuk skrin akhir kelihatan awal dan tiada
/// "loncatan" susun atur bila data tiba.
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
    ),
  );
}

/// Kad ralat "gagal muat papan pemuka" dengan butang cuba semula.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gagal memuat papan pemuka.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Cuba lagi')),
          ],
        ),
      ),
    );
  }
}
