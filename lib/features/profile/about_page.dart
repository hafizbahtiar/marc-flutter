import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _developerUrl = 'https://hafizbahtiar.com';

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
                  'MARC ialah aplikasi rasmi untuk ahli MAIWP berkongsi '
                  'maklumat, pengumuman, dan berhubung sesama ahli.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    '© ${DateTime.now().year} MAIWP',
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
              ],
            );
          },
        ),
      ),
    );
  }
}
