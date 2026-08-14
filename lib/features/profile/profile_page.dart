import 'package:flutter/material.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';
import 'package:marc/shared/widgets/app_action_sheet.dart';
import 'package:marc/features/profile/widgets/avatar_crop_page.dart';
import 'package:marc/features/profile/avatar_service.dart';
import 'package:marc/core/error_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/theme_mode_provider.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/features/profile/widgets/verify_email_banner.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/member_avatar.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _signingOut = false;
  bool _avatarBusy = false;

  /// Tukar/buang gambar profil.
  ///
  /// Selepas berjaya, `myProfileProvider` di-refresh dan DITUNGGU sebelum
  /// penunjuk sibuk dimatikan — jadi avatar baharu dah ada sebelum
  /// spinner hilang, bukan muncul selepas satu kelipan avatar lama.
  Future<void> _changeAvatar() async {
    if (_avatarBusy) return;
    final profile = ref.read(myProfileProvider).valueOrNull;
    if (profile == null) return;

    final action = await showAppActionSheet<_AvatarAction>(
      context,
      title: 'Gambar profil',
      actions: [
        const AppSheetAction(
          value: _AvatarAction.pick,
          label: 'Pilih dari galeri',
          icon: Icons.photo_library_outlined,
        ),
        if (profile.avatarUrl != null)
          const AppSheetAction(
            value: _AvatarAction.remove,
            label: 'Buang gambar',
            icon: Icons.delete_outline,
            isDestructive: true,
          ),
      ],
    );
    if (action == null || !mounted) return;

    setState(() => _avatarBusy = true);
    try {
      final service = ref.read(avatarServiceProvider);

      if (action == _AvatarAction.remove) {
        await service.remove();
        await _refreshAvatar();
        if (mounted) MySnackBar.success(context, 'Gambar profil dibuang.');
        return;
      }

      final picked = await service.pick();
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final cropped = await AvatarCropPage.open(context, bytes);
      if (cropped == null) return;

      await service.upload(cropped);
      await _refreshAvatar();
      if (mounted) MySnackBar.success(context, 'Gambar profil dikemas kini.');
    } catch (e) {
      if (mounted) {
        MySnackBar.error(
          context,
          e is DioException
              ? extractErrorMessage(e)
              : 'Gagal kemas kini gambar profil.',
        );
      }
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  /// Tunggu profil segar SEBELUM pemanggil matikan penunjuk sibuk.
  /// `invalidate` sahaja pulang serta-merta, jadi spinner akan hilang
  /// sementara avatar lama masih terpapar.
  Future<void> _refreshAvatar() async {
    ref.invalidate(myProfileProvider);
    await ref.read(myProfileProvider.future);
    // Senarai ahli papar avatar sama — tanpa ni ia kekal lama sehingga
    // logout/restart (provider bukan autoDispose).
    ref.invalidate(membersProvider);
  }

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
                  avatarUrl: p?.avatarUrl,
                  onTapAvatar: p == null ? null : _changeAvatar,
                  avatarBusy: _avatarBusy,
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
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('Aktiviti Saya'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/my-activities'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Sijil Saya'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/my-certificates'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('Sokong MARC'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/donate'),
                ),
                // Management sahaja — backend 403 juga, ni cuma elak
                // tunjuk pintu yang terkunci.
                if (p?.isManagement ?? false)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    leading: const Icon(Icons.history),
                    title: const Text('Jejak Audit'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/audit-logs'),
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
    required this.avatarUrl,
    this.onTapAvatar,
    this.avatarBusy = false,
  });

  final String? name;
  final String? roleName;
  final bool isManagement;
  final String? avatarUrl;
  final VoidCallback? onTapAvatar;
  final bool avatarBusy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            MemberAvatar(
              label: name ?? '?',
              avatarUrl: avatarUrl,
              radius: 30,
              onTap: avatarBusy ? null : onTapAvatar,
            ),
            if (avatarBusy)
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            else if (onTapAvatar != null)
              // Affordance: tanpa lencana ni tiada apa yang menunjukkan
              // avatar boleh diketuk.
              Positioned(
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 12,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
          ],
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

enum _AvatarAction { pick, remove }
