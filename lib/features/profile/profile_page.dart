import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/theme_mode_provider.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/features/profile/widgets/verify_email_banner.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _signingOut = false;

  Future<void> _handleLogout() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Log keluar',
      message: 'Anda pasti mahu log keluar?',
      confirmLabel: 'Log keluar',
      isDestructive: true,
    );
    if (!ok || _signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(authServiceProvider).signOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(myProfileProvider);
    final loading = profile.isLoading;
    final p = profile.valueOrNull;
    final email = p?.email ?? '';

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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            if (profile.hasError) ...[
              _ProfileFetchErrorCard(
                onRetry: () => ref.invalidate(myProfileProvider),
              ),
              const SizedBox(height: 28),
            ] else ...[
              Skeletonizer(
                enabled: loading,
                child: _Header(
                  name: p?.displayName ?? (loading ? 'Nama Ahli' : null),
                  roleName: p?.roleName ?? (loading ? 'Ahli' : null),
                  isManagement: p?.isManagement ?? false,
                ),
              ),
              const SizedBox(height: 28),
              const VerifyEmailBanner(),
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
                      value:
                          p?.memberId ?? (loading ? 'MARC2026/08/0000' : '-'),
                    ),
                    _InfoRow(
                      label: 'Status email',
                      value: verified ? 'Disahkan' : 'Belum disahkan',
                      valueColor: verified
                          ? scheme.primary
                          : Theme.of(
                              context,
                            ).extension<AppSemanticColors>()!.warning,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            _InfoCard(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Mod Gelap'),
                  value: ref.watch(themeModeProvider) == ThemeMode.dark,
                  onChanged: (isDark) =>
                      ref.read(themeModeProvider.notifier).setDark(isDark),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('Donate'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/donate'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Soalan Lazim'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/faq'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Tentang'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/about'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _signingOut ? null : _handleLogout,
              icon: _signingOut
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator.adaptive(),
                    )
                  : const Icon(Icons.logout, size: 20),
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

class _ProfileFetchErrorCard extends StatelessWidget {
  const _ProfileFetchErrorCard({required this.onRetry});

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
    // Material (bukan Container+BoxDecoration) — ListTile lukis ink
    // splash pada Material ANCESTOR terdekat; kalau bg+radius kat
    // Container/DecoratedBox biasa, splash terlukis DI BAWAH decoration
    // tu (tersorok). Jadikan card ni sendiri Material elak isu tu.
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
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
