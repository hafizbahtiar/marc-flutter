import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/core/theme_mode_provider.dart';
import 'package:marc/core/theme_switch_reveal.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/ui/dialog/confirm_dialog.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';
import 'package:marc/shared/ui/widgets/settings_section.dart';

/// Padding kiri/kanan seragam utk semua baris dalam [SettingsCard] -
/// kad tu sendiri dah ada radius 16, jadi tile perlukan inset sikit.
const _tilePadding = EdgeInsets.symmetric(horizontal: 18);

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
            const _SettingsGroup(
              label: 'Paparan',
              tiles: [_ThemeTile()],
            ),
            const _SettingsGroup(
              label: 'Sambungan',
              tiles: [
                _NavTile(
                  icon: Icons.send_outlined,
                  label: 'Telegram',
                  route: '/telegram-link',
                ),
              ],
            ),
            const _SettingsGroup(
              label: 'Akaun',
              tiles: [
                // Sesi aktif - self-service "log keluar device ni", beza
                // drpd butang Log keluar di bawah (device ini sahaja) dan
                // drpd logout-all.
                _NavTile(
                  icon: Icons.devices_outlined,
                  label: 'Sesi Aktif',
                  route: '/profile/sessions',
                ),
              ],
            ),
            // Root-level config org-wide (bukan management umum) - superadmin
            // SAHAJA, padanan siling backend `authz.IsAtLeastRole(...,
            // "superadmin")`. Kumpulan BERASINGAN drpd yang lain, elak kelirukan
            // ahli management biasa dgn pintu yang terkunci utk mereka.
            if (ref.watch(isSuperAdminProvider))
              const _SettingsGroup(
                label: 'Sistem',
                tiles: [
                  _NavTile(
                    icon: Icons.block_outlined,
                    label: 'Domain Emel Disekat',
                    route: '/admin/blocked-email-domains',
                  ),
                  _NavTile(
                    icon: Icons.apartment_outlined,
                    label: 'Bahagian/Jabatan',
                    route: '/admin/departments',
                  ),
                ],
              ),
            const _SettingsGroup(
              label: 'Bantuan',
              tiles: [
                _NavTile(
                  icon: Icons.help_outline,
                  label: 'Soalan Lazim',
                  route: '/faq',
                ),
                _NavTile(
                  icon: Icons.info_outline,
                  label: 'Tentang',
                  route: '/about',
                ),
              ],
            ),
            // Dua tindakan yang tak boleh "tekan tersilap" dikumpul di
            // hujung senarai, jauh drpd navigasi biasa.
            _SettingsGroup(
              label: 'Zon Bahaya',
              tiles: [
                ListTile(
                  contentPadding: _tilePadding,
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
            const SizedBox(height: 12),
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

/// Label + kad + jarak bawah dalam SATU widget. Sebelum ni jarak antara
/// kumpulan datang drpd `SizedBox` manual yang senang tertinggal (kad
/// "Bantuan" dulu melekat pada kumpulan seterusnya) - sekarang mustahil
/// terlepas sebab ia sebahagian drpd kumpulan itu sendiri.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.label, required this.tiles});

  final String label;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SettingsGroupLabel(label), SettingsCard(children: tiles)],
      ),
    );
  }
}

/// Baris navigasi standard (ikon - tajuk - chevron - push route).
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: _tilePadding,
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}

/// Toggle mod gelap dgn peralihan radial (lihat [ThemeSwitchReveal]).
///
/// Seluruh baris boleh ditap - bukan switch sahaja - sebab animasi perlu
/// tahu kedudukan jari, dan sasaran tap sebesar baris lebih senang kena.
class _ThemeTile extends ConsumerStatefulWidget {
  const _ThemeTile();

  @override
  ConsumerState<_ThemeTile> createState() => _ThemeTileState();
}

class _ThemeTileState extends ConsumerState<_ThemeTile> {
  Offset _lastPointer = Offset.zero;

  Future<void> _toggle(bool isDark) async {
    final reveal = ThemeSwitchReveal.maybeOf(context);
    // `setDark` tukar state secara segerak, cuma tulis ke prefs yang
    // async - jadi selamat untuk tak di-await masa animasi bermula.
    void apply() =>
        unawaited(ref.read(themeModeProvider.notifier).setDark(isDark));

    if (reveal == null) {
      apply();
      return;
    }
    await reveal.reveal(globalPosition: _lastPointer, applyThemeChange: apply);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    // `Listener` (bukan GestureDetector) - ia tak masuk gesture arena,
    // jadi tap tetap sampai ke ListTile untuk ink splash yang normal.
    return Listener(
      onPointerDown: (event) => _lastPointer = event.position,
      child: ListTile(
        contentPadding: _tilePadding,
        leading: Icon(isDark ? Icons.dark_mode : Icons.dark_mode_outlined),
        title: const Text('Mod Gelap'),
        // IgnorePointer - switch cuma paparan status; tap dikendali oleh
        // baris supaya kedudukan jari sentiasa direkod.
        trailing: IgnorePointer(
          child: Switch.adaptive(value: isDark, onChanged: (_) {}),
        ),
        onTap: () => _toggle(!isDark),
      ),
    );
  }
}
