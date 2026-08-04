import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc_flutter/app/theme.dart';
import 'package:marc_flutter/features/auth/auth_providers.dart';
import 'package:marc_flutter/features/profile/profile_providers.dart';
import 'package:marc_flutter/features/profile/widgets/verify_email_banner.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final profile = ref.watch(myProfileProvider);
    final p = profile.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profil',
            onPressed: () => context.push('/edit-profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          children: [
            const VerifyEmailBanner(),
            const SizedBox(height: 24),
            Text(
              p?.displayName ?? '(Tiada nama)',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 6),
            if (p != null) _RoleChip(name: p.roleName, category: p.category),
            const SizedBox(height: 28),
            _Field(label: 'EMAIL', value: email),
            const SizedBox(height: 20),
            _Field(label: 'NO. TELEFON', value: p?.phone ?? '—'),
            const SizedBox(height: 20),
            _Field(label: 'NO. AHLI', value: p?.memberId ?? '—'),
            const SizedBox(height: 20),
            _Field(
              label: 'STATUS EMAIL',
              value: switch (profile) {
                AsyncData(:final value) =>
                  (value?.emailVerified ?? false)
                      ? 'Disahkan'
                      : 'Belum disahkan',
                AsyncError() => '—',
                _ => '…',
              },
              valueColor: (p?.emailVerified ?? false)
                  ? AppColors.accentDark
                  : AppColors.warning,
            ),
            const SizedBox(height: 40),
            OutlinedButton.icon(
              onPressed: () => ref.read(authServiceProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Log keluar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.name, required this.category});

  final String name;
  final String category;

  @override
  Widget build(BuildContext context) {
    final isManagement = category == 'management';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isManagement
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: isManagement ? AppColors.accentDark : AppColors.muted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: valueColor ?? AppColors.ink),
        ),
      ],
    );
  }
}
