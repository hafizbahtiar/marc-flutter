import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/profile/profile_providers.dart';

/// Bungkus skrin yang perlukan `profile.status == 'approved'` (dan
/// pilihan email disahkan) — papar mesej JELAS + pautan ke tab Utama,
/// bukan biar tab tu panggil API terus dan 403 jatuh sebagai ralat
/// generik "gagal memuat" yang tak terangkan sebab (isu sebenar 2026-08-15
/// selepas Notifikasi/Aktiviti jadi tab bottom nav — boleh dicapai
/// SEBELUM approve, tak macam dulu bila ia terkurung dalam Feed yang
/// dah ada gate sendiri).
///
/// Versi RINGAN drpd gate dalam `feed_page.dart`
/// (`_PendingStatusView`/`_EmailNotVerifiedView`) — TIADA butang bayar
/// (Feed kekal tempat kanonik urusan pendaftaran/bayaran), cuma arahan
/// pergi ke situ.
class ApprovalGate extends ConsumerWidget {
  const ApprovalGate({
    super.key,
    required this.title,
    required this.child,
    this.requireVerifiedEmail = false,
  });

  /// Tajuk AppBar skrin ni (cth "Notifikasi", "Aktiviti") — gate
  /// menggantikan SELURUH skrin (Scaffold sendiri) bila tak lulus,
  /// padanan pola `feed_page.dart`, jadi tajuk perlu dihantar terus.
  final String title;

  final Widget child;

  /// Sesetengah skrin (Notifikasi) perlukan email disahkan JUGA (bukan
  /// setakat approved) — padanan `RequireVerifiedEmail` backend. Skrin
  /// lain (Aktiviti) tak perlu.
  final bool requireVerifiedEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (status: profileStatus, emailVerified: profileEmailVerified) = ref
        .watch(
          myProfileProvider.select(
            (p) => (
              status: p.valueOrNull?.status,
              emailVerified: p.valueOrNull?.emailVerified,
            ),
          ),
        );

    if (profileStatus != null && profileStatus != 'approved') {
      final isRejected = profileStatus == 'rejected';
      return _GateScaffold(
        title: title,
        icon: isRejected ? Icons.error_outline : Icons.hourglass_empty,
        iconColor: (theme) => isRejected
            ? theme.colorScheme.error
            : theme.extension<AppSemanticColors>()!.warning,
        message: isRejected
            ? 'Pendaftaran anda tidak diluluskan. Sila hubungi pihak pengurusan MARC.'
            : 'Skrin ini akan tersedia sebaik pendaftaran anda diluluskan pengurusan.',
        // Ahli pending mungkin masih kena bayar/semak status — Feed
        // (tab Utama) ada gate penuh dgn butang bayar + "Semak semula".
        showGoToFeed: !isRejected,
      );
    }

    if (requireVerifiedEmail && profileEmailVerified == false) {
      return _GateScaffold(
        title: title,
        icon: Icons.mark_email_unread_outlined,
        iconColor: (theme) => theme.extension<AppSemanticColors>()!.warning,
        message:
            'Sila sahkan email anda dahulu untuk akses skrin ini — pergi ke tab Utama.',
        showGoToFeed: true,
      );
    }

    return child;
  }
}

class _GateScaffold extends StatelessWidget {
  const _GateScaffold({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.message,
    required this.showGoToFeed,
  });

  final String title;
  final IconData icon;
  final Color Function(ThemeData) iconColor;
  final String message;
  final bool showGoToFeed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: iconColor(theme)),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                if (showGoToFeed) ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => context.go('/feed'),
                    child: const Text('Pergi ke Utama'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
