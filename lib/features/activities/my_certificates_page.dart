import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:marc/features/activities/activity_format.dart';
import 'package:marc/features/activities/activity_models.dart';
import 'package:marc/features/activities/activity_providers.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

/// Sijil ahli, dengan muat turun PDF.
///
/// "Muat turun" di sini bermakna MEMBUKA pautan bertandatangan yang
/// backend pulangkan, bukan menulis fail ke storan peranti: endpoint
/// memulangkan `{"url": ...}` ke R2 dan pelayar/pelihat PDF sistem yang
/// mengendalikan selebihnya. Tiada kebenaran storan, tiada pakej baharu.
class MyCertificatesPage extends ConsumerStatefulWidget {
  const MyCertificatesPage({super.key});

  @override
  ConsumerState<MyCertificatesPage> createState() => _MyCertificatesPageState();
}

class _MyCertificatesPageState extends ConsumerState<MyCertificatesPage> {
  /// Id sijil yang sedang menunggu pautan — supaya ketukan berulang pada
  /// baris yang sama tidak menghantar permintaan bertindih.
  final _busy = <String>{};

  Future<void> _refresh() async {
    ref.invalidate(myCertificatesProvider);
    await ref.read(myCertificatesProvider.future);
  }

  Future<void> _open(MyCertificate cert) async {
    if (_busy.contains(cert.id)) return;
    setState(() => _busy.add(cert.id));
    try {
      // Server yang menentukan sama ada fail sudah ada — `file_ready`
      // dalam senarai boleh sudah basi (fasa 2 mungkin siap selepas
      // senarai dimuatkan), jadi ketukan sentiasa bertanya.
      final result = await ref
          .read(certificateRepositoryProvider)
          .fileUrl(cert.id);
      if (!mounted) return;

      if (!result.isOk) {
        MySnackBar.error(context, result.message!);
        return;
      }

      final uri = Uri.tryParse(result.url!);
      final opened =
          uri != null &&
          uri.scheme == 'https' &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) {
        MySnackBar.error(context, 'Tiada aplikasi untuk membuka sijil.');
      }
    } catch (_) {
      if (mounted) MySnackBar.error(context, 'Gagal buka sijil.');
    } finally {
      if (mounted) setState(() => _busy.remove(cert.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final certificates = ref.watch(myCertificatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sijil Saya')),
      body: SafeArea(
        child: certificates.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (var i = 0; i < 3; i++)
                  _CertificateCard(
                    certificate: _placeholderCertificate,
                    busy: false,
                    onTap: () {},
                  ),
              ],
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Gagal memuat sijil anda.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return RefreshIndicator.adaptive(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 100,
                        horizontal: 28,
                      ),
                      child: Center(
                        child: Text(
                          'Belum ada sijil. Sijil diterbitkan selepas '
                          'aktiviti tamat dan kehadiran anda mencukupi.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final cert = rows[index];
                  return _CertificateCard(
                    certificate: cert,
                    busy: _busy.contains(cert.id),
                    onTap: () => _open(cert),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

final _placeholderCertificate = MyCertificate(
  id: '0',
  activityId: '0',
  serial: 'MARC-2026-000123',
  recipientName: '',
  activityTitle: 'Kejohanan Badminton Tahunan',
  categoryName: 'Sukan',
  activityDate: DateTime.now(),
  issuedAt: DateTime.now(),
  fileReady: true,
);

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({
    required this.certificate,
    required this.busy,
    required this.onTap,
  });

  final MyCertificate certificate;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = certificate;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        onTap: busy ? null : onTap,
        title: Text(c.activityTitle, style: theme.textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${c.serial} • ${formatDate(c.activityDate)}'),
              if (!c.fileReady)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Sedang disediakan',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        trailing: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined),
      ),
    );
  }
}
