import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';

class TelegramLinkPage extends ConsumerStatefulWidget {
  const TelegramLinkPage({super.key});

  @override
  ConsumerState<TelegramLinkPage> createState() => _TelegramLinkPageState();
}

class _TelegramLinkPageState extends ConsumerState<TelegramLinkPage> {
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final authService = ref.read(authServiceProvider);
    final result = await authService.requestTelegramLinkToken();
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success || result.deepLink == null) {
      setState(() => _error = result.error ?? 'Gagal jana pautan. Cuba lagi.');
      return;
    }
    await launchUrl(
      Uri.parse(result.deepLink!),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _disconnect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final authService = ref.read(authServiceProvider);
    final result = await authService.deleteTelegramLink();
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      setState(() => _error = result.error ?? 'Gagal nyahikat. Cuba lagi.');
      return;
    }
    ref.invalidate(myProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

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
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  linked ? Icons.check_circle : Icons.link,
                  size: 48,
                  color: linked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  linked
                      ? 'Disambungkan${profile.telegramUsername != null ? ' sbg @${profile.telegramUsername}' : ''}'
                      : 'Sambungkan akaun Telegram anda utk menerima notifikasi tambahan.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: _busy ? null : (linked ? _disconnect : _connect),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(linked ? 'Nyahikat' : 'Sambung Telegram'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
