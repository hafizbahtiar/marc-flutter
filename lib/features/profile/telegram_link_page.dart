import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

class TelegramLinkPage extends ConsumerStatefulWidget {
  const TelegramLinkPage({super.key});

  @override
  ConsumerState<TelegramLinkPage> createState() => _TelegramLinkPageState();
}

class _TelegramLinkPageState extends ConsumerState<TelegramLinkPage>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Binding SEBENAR berlaku di luar app (ahli tekan /start dlm Telegram),
  // dan backend TIADA cara push balik ke app bila itu siap -- webhook
  // Telegram-ke-server, bukan server-ke-app. Titik SATU-SATUNYA kita
  // tahu utk cuba semak semula ialah bila app kembali ke latar depan
  // (ahli swipe balik selepas tekan /start). Tanpa ni skrin kekal papar
  // keadaan lama sehingga ahli tinggalkan & masuk semula skrin secara
  // manual.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(myProfileProvider);
    }
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    final authService = ref.read(authServiceProvider);
    final result = await authService.requestTelegramLinkToken();
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success || result.deepLink == null) {
      MySnackBar.error(
        context,
        result.error ?? 'Gagal jana pautan. Cuba lagi.',
      );
      return;
    }
    await launchUrl(
      Uri.parse(result.deepLink!),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    final authService = ref.read(authServiceProvider);
    final result = await authService.deleteTelegramLink();
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      MySnackBar.error(context, result.error ?? 'Gagal nyahikat. Cuba lagi.');
      return;
    }
    ref.invalidate(myProfileProvider);
    MySnackBar.success(context, 'Akaun Telegram dinyahikat.');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Telegram')),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Gagal muat status.')),
          data: (profile) {
            // profile null cuma bila belum log masuk -- skrin ni duduk
            // atas laluan berautentikasi, jadi ni sepatutnya tak
            // berlaku dlm guna sebenar. Kekal sbg gard jenis, bukan
            // aliran dijangka.
            if (profile == null) {
              return const Center(child: Text('Log masuk diperlukan.'));
            }
            final linked = profile.telegramLinked;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Text(
                  'Sambungkan akaun Telegram anda ke akaun MARC. Ini asas '
                  'untuk ciri akan datang - notifikasi tambahan terus ke '
                  'Telegram, dan pengesahan dua langkah (2FA) semasa log '
                  'masuk. Buat masa ini binding sahaja belum menghantar '
                  'notifikasi apa-apa.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                // Material (bukan Container+BoxDecoration) - padanan
                // _InfoCard di profile_page.dart, elak splash ink
                // tersorok bawah decoration.
                Material(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: linked
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHigh,
                      child: Icon(
                        linked ? Icons.check : Icons.send_outlined,
                        color: linked
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(linked ? 'Disambungkan' : 'Belum disambung'),
                    subtitle: Text(
                      linked
                          ? (profile.telegramUsername != null
                                ? '@${profile.telegramUsername}'
                                : 'Akaun Telegram disambungkan')
                          : 'Belum ada akaun Telegram disambungkan',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : (linked ? _disconnect : _connect),
                  icon: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: linked
                                ? scheme.onErrorContainer
                                : scheme.onPrimary,
                          ),
                        )
                      : Icon(linked ? Icons.link_off : Icons.send_outlined),
                  label: Text(linked ? 'Nyahikat' : 'Sambung Telegram'),
                  style: linked
                      ? FilledButton.styleFrom(
                          backgroundColor: scheme.errorContainer,
                          foregroundColor: scheme.onErrorContainer,
                        )
                      : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
