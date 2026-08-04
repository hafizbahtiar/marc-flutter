import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc_flutter/app/theme.dart';
import 'package:marc_flutter/features/profile/profile_providers.dart';
import 'package:marc_flutter/features/profile/widgets/verify_email_banner.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          children: [
            const VerifyEmailBanner(),
            const SizedBox(height: 24),
            _Field(label: 'EMAIL', value: email),
            const SizedBox(height: 20),
            _Field(
              label: 'NO. AHLI',
              value: profile.valueOrNull?.memberId ?? '—',
            ),
            const SizedBox(height: 20),
            _Field(
              label: 'STATUS EMAIL',
              value: switch (profile) {
                AsyncData(:final value) =>
                  (value?.emailVerified ?? false) ? 'Disahkan' : 'Belum disahkan',
                AsyncError() => '—',
                _ => '…',
              },
              valueColor: (profile.valueOrNull?.emailVerified ?? false)
                  ? AppColors.accentDark
                  : AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                letterSpacing: 1.5,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: valueColor ?? AppColors.ink,
              ),
        ),
      ],
    );
  }
}
