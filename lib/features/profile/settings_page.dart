import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/core/theme_mode_provider.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';
import 'package:marc/shared/widgets/settings_section.dart';

/// Hub tetapan/tindakan akaun - dipisah drpd `ProfilePage` (yang kekal
/// fokus pada info profil + Komuniti/Aktiviti/Kewangan/Pengurusan) supaya
/// skrin tu tak makin sarat. Diakses via ikon gear pada AppBar Profil.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _signingOut = false;
  bool _requestingDeletion = false;

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

  Future<void> _handleRequestDeletion() async {
    if (_requestingDeletion) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Padam akaun',
      message:
          'Ini menghantar PERMINTAAN pemadaman akaun - bukan padam '
          'serta-merta. Pasukan MARC akan proses & hubungi anda. '
          'Anda pasti mahu teruskan?',
      confirmLabel: 'Hantar',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _requestingDeletion = true);
    try {
      await ref.read(profileRepositoryProvider).requestAccountDeletion();
      if (mounted) {
        MySnackBar.success(
          context,
          'Permintaan pemadaman akaun direkod. Kami akan hubungi anda.',
        );
      }
    } catch (e) {
      if (mounted) {
        MySnackBar.error(
          context,
          e is DioException
              ? extractErrorMessage(e)
              : 'Gagal hantar permintaan. Cuba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _requestingDeletion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tetapan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            SettingsGroupLabel('Paparan'),
            SettingsCard(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Mod Gelap'),
                  value: ref.watch(themeModeProvider) == ThemeMode.dark,
                  onChanged: (isDark) =>
                      ref.read(themeModeProvider.notifier).setDark(isDark),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsGroupLabel('Sambungan'),
            SettingsCard(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  leading: const Icon(Icons.send_outlined),
                  title: const Text('Telegram'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/telegram-link'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsGroupLabel('Bantuan'),
            SettingsCard(
              children: [
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
            // Root-level config org-wide (bukan management umum) - superadmin
            // SAHAJA, padanan siling backend `authz.IsAtLeastRole(...,
            // "superadmin")`. Kumpulan BERASINGAN drpd yang lain, elak kelirukan
            // ahli management biasa dgn pintu yang terkunci utk mereka.
            if (ref.watch(isSuperAdminProvider)) ...[
              SettingsGroupLabel('Sistem'),
              SettingsCard(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    leading: const Icon(Icons.block_outlined),
                    title: const Text('Domain Emel Disekat'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/admin/blocked-email-domains'),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    leading: const Icon(Icons.apartment_outlined),
                    title: const Text('Bahagian/Jabatan'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/admin/departments'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            SettingsGroupLabel('Akaun'),
            SettingsCard(
              children: [
                // Sesi aktif - self-service "log keluar device ni",
                // beza drpd butang Log keluar di bawah (device ini
                // sahaja) dan drpd logout-all.
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  leading: const Icon(Icons.devices_outlined),
                  title: const Text('Sesi Aktif'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/sessions'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  leading: Icon(
                    Icons.person_remove_outlined,
                    color: scheme.error,
                  ),
                  title: Text(
                    'Padam Akaun',
                    style: TextStyle(color: scheme.error),
                  ),
                  trailing: _requestingDeletion
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : null,
                  onTap: _requestingDeletion ? null : _handleRequestDeletion,
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
