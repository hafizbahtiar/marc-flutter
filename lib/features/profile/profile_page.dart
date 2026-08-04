import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc_flutter/features/auth/auth_providers.dart';
import 'package:marc_flutter/features/profile/profile_providers.dart';
import 'package:marc_flutter/features/profile/widgets/verify_email_banner.dart';
import 'package:marc_flutter/shared/widgets/confirm_dialog.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final profile = ref.watch(myProfileProvider);
    final loading = profile.isLoading;
    final p = profile.valueOrNull;

    final verified = p?.emailVerified ?? false;

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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const VerifyEmailBanner(),
            const SizedBox(height: 16),
            Skeletonizer(
              enabled: loading,
              child: _Header(
                name: p?.displayName ?? (loading ? 'Nama Ahli' : null),
                roleName: p?.roleName ?? (loading ? 'Ahli' : null),
                isManagement: p?.isManagement ?? false,
              ),
            ),
            const SizedBox(height: 28),
            Skeletonizer(
              enabled: loading,
              child: _InfoCard(
                children: [
                  _InfoRow(label: 'Email', value: email),
                  _InfoRow(
                    label: 'No. telefon',
                    value: p?.phone ?? (loading ? '0100000000' : '-'),
                  ),
                  _InfoRow(
                    label: 'No. ahli',
                    value: p?.memberId ?? (loading ? 'MARC2026/08/0000' : '-'),
                  ),
                  _InfoRow(
                    label: 'Status email',
                    value: verified ? 'Disahkan' : 'Belum disahkan',
                    valueColor: verified
                        ? scheme.primary
                        : const Color(0xFF8A5A00),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Log keluar',
                  message: 'Anda pasti mahu log keluar?',
                  confirmLabel: 'Log keluar',
                  isDestructive: true,
                );
                if (ok) await ref.read(authServiceProvider).signOut();
              },
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Log keluar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                minimumSize: const Size.fromHeight(52),
                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.roleName,
    required this.isManagement,
  });

  final String? name;
  final String? roleName;
  final bool isManagement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          child: Text(
            initial,
            style: TextStyle(
              color: scheme.primary,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name ?? '(Tiada nama)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              if (roleName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isManagement
                        ? scheme.primary.withValues(alpha: 0.12)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleName!,
                    style: TextStyle(
                      color: isManagement
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: valueColor ?? scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
