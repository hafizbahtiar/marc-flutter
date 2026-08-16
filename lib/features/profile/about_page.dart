import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _developerUrl = 'https://hafizbahtiar.com';

/// Penafian "bukan rasmi".
///
/// Dipaparkan sebagai kotak bertona dan bukan teks kecil di bahagian
/// bawah: perkara yang perlu dinyatakan ialah apa yang app ni BUKAN, dan
/// penafian yang tersembunyi tak menafikan apa-apa pun.
class _NotOfficialNotice extends StatelessWidget {
  const _NotOfficialNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ini bukan aplikasi rasmi MAIWP. MARC dibangunkan secara '
              'sukarela sebagai projek peribadi, dan tidak diurus, ditaja '
              'atau disahkan oleh MAIWP.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang')),
      body: SafeArea(
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              children: [
                Center(
                  child: Image.asset(
                    'assets/splash/logo.png',
                    height: 96,
                    errorBuilder: (_, _, _) => const SizedBox(height: 96),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    info?.appName ?? 'MARC',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    info == null
                        ? ' '
                        : 'Versi ${info.version} (${info.buildNumber})',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'MARC ialah aplikasi komuniti untuk berkongsi maklumat, '
                  'pengumuman, dan berhubung sesama ahli.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Dibina secara sukarela atas permintaan En. Ezri, yang '
                  'mencetuskan idea app ini.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                // Penafian ni WAJIB kekal. MARC dibangunkan secara sukarela
                // dan BUKAN aplikasi rasmi MAIWP — tanpa baris ni, app yang
                // ada logo, senarai ahli dan pengumuman memang akan dibaca
                // sebagai rasmi. Ia juga mesti selari dengan halaman
                // sumbangan, yang menyatakan derma pergi kepada pembangun
                // dan bukan kepada MAIWP.
                const _NotOfficialNotice(),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    '© ${DateTime.now().year} Hafiz Bahtiar',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Dibangunkan oleh ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    InkWell(
                      onTap: () => launchUrl(
                        Uri.parse(_developerUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        'hafizbahtiar.com',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () =>
                          context.push('/legal/terma-dan-syarat'),
                      child: const Text('Terma & Syarat'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/legal/dasar-privasi'),
                      child: const Text('Dasar Privasi'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
