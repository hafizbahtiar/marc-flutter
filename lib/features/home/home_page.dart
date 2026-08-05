import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/features/profile/widgets/verify_email_banner.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final loading = profile.isLoading;
    final p = profile.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Utama')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Text(
              'SELAMAT DATANG',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 6),
            if (profile.hasError)
              _ProfileErrorCard(
                onRetry: () => ref.invalidate(myProfileProvider),
              )
            else ...[
              Skeletonizer(
                enabled: loading,
                child: Text(
                  p?.displayName ?? 'Ahli MARC',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: 28),
              Skeletonizer(
                enabled: loading,
                child: _MemberCard(memberId: p?.memberId ?? 'MARC2026/08/0000'),
              ),
            ],
            const SizedBox(height: 20),
            const VerifyEmailBanner(),
          ],
        ),
      ),
    );
  }
}

class _ProfileErrorCard extends StatelessWidget {
  const _ProfileErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Gagal muat profil.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Cuba lagi')),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 18,
                color: scheme.onPrimary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Text(
                'NO. AHLI',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            memberId,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: scheme.onPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
