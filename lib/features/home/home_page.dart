import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc_flutter/app/theme.dart';
import 'package:marc_flutter/features/profile/profile_providers.dart';
import 'package:marc_flutter/features/profile/widgets/verify_email_banner.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final name = profile.valueOrNull?.displayName;

    return Scaffold(
      appBar: AppBar(title: const Text('Utama')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          children: [
            const VerifyEmailBanner(),
            const SizedBox(height: 24),
            Text(
              name == null ? 'Selamat datang' : 'Hai, $name',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 32),
            _MemberIdCard(
              child: profile.when(
                loading: () => const _MemberIdText(value: '…'),
                error: (_, _) => const _MemberIdText(value: '—'),
                data: (p) => _MemberIdText(value: p?.memberId ?? '—'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberIdCard extends StatelessWidget {
  const _MemberIdCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NO. AHLI',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  letterSpacing: 1.5,
                ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _MemberIdText extends StatelessWidget {
  const _MemberIdText({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.accentDark,
          ),
    );
  }
}
