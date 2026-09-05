import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/features/activities/manage/management_gate.dart';
import 'package:marc/features/admin/blocked_email_domains_models.dart';
import 'package:marc/features/admin/blocked_email_domains_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/utils/relative_time.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';
import 'package:marc/shared/ui/dialog/app_dialog_field.dart';
import 'package:marc/shared/ui/dialog/confirm_dialog.dart';
import 'package:marc/shared/ui/sheet/app_form_sheet.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

/// Skrin urus domain emel pelupusan (`blocked_email_domains`) -
/// superadmin SAHAJA (bukan management umum): jadual ni kawal SIAPA
/// BOLEH DAFTAR langsung, root-level config yang kesan seluruh sistem
/// (padanan gate backend `authz.IsAtLeastRole(..., "superadmin")`,
/// `internal/http/handlers/blocked_email_domains.go`).
///
/// Ni PELENGKAP sahaja - pertahanan UTAMA ialah senarai statik terbenam
/// (`internal/disposableemail`, ~8,200 domain) yang tak boleh diurus
/// dari sini langsung (perlu deploy kod). Skrin ni untuk domain BAHARU
/// yang senarai statik terlepas.
class BlockedEmailDomainsPage extends ConsumerWidget {
  const BlockedEmailDomainsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ManagementGate(
      title: 'Domain Emel Disekat',
      child: Consumer(
        builder: (context, ref, _) {
          // rolesProvider (sumber isSuperAdminProvider) ialah panggilan
          // API BERASINGAN drpd /me - semak keadaan dia SENDIRI di sini
          // (bukan cuma isSuperAdminProvider == false), kalau tidak
          // superadmin sebenar nampak "akses ditolak" sepanjang /roles
          // perlahan/gagal, jalan mati tanpa cuba semula (Opus verify
          // 2026-08-15, padanan pembaikan activity_categories_page.dart).
          final roles = ref.watch(rolesProvider);
          if (roles.isLoading) {
            return const Scaffold(
              appBar: _DomainsAppBar(),
              body: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          if (roles.hasError) {
            return Scaffold(
              appBar: const _DomainsAppBar(),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Gagal menyemak kebenaran anda.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(rolesProvider),
                        child: const Text('Cuba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (!ref.watch(isSuperAdminProvider)) {
            return const Scaffold(
              appBar: _DomainsAppBar(),
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Skrin ini untuk superadmin sahaja.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          return const _DomainsBody();
        },
      ),
    );
  }
}

class _DomainsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DomainsAppBar();

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Domain Emel Disekat'));

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _DomainsBody extends ConsumerWidget {
  const _DomainsBody();

  Future<void> _openAdd(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<_DomainFormState>();
    final domain = await showAppFormSheet<String>(
      context,
      title: 'Sekat Domain',
      content: _DomainForm(key: formKey),
      actions: (ctx) => [
        AppDialogAction(
          label: 'Batal',
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        AppDialogAction(
          label: 'Sekat',
          isPrimary: true,
          onPressed: () => formKey.currentState?.submit(),
        ),
      ],
    );
    if (domain == null || !context.mounted) return;

    final res = await ref
        .read(blockedEmailDomainsRepositoryProvider)
        .add(domain);
    if (!context.mounted) return;
    if (res.isOk) {
      MySnackBar.success(context, 'Domain "$domain" disekat.');
    } else {
      MySnackBar.error(context, res.message ?? 'Gagal tambah domain.');
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    BlockedEmailDomain d,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Buang sekatan',
      message:
          'Buang sekatan pada "${d.domain}"? Ahli akan boleh daftar '
          'guna alamat domain ini semula.',
      confirmLabel: 'Buang',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    final res = await ref
        .read(blockedEmailDomainsRepositoryProvider)
        .remove(d.domain);
    if (!context.mounted) return;
    if (!res.isOk) {
      MySnackBar.error(context, res.message ?? 'Gagal buang domain.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final domains = ref.watch(blockedEmailDomainsProvider);

    return Scaffold(
      appBar: const _DomainsAppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: domains.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat senarai domain.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        ref.invalidate(blockedEmailDomainsProvider),
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Tiada domain tambahan disekat.\n\nSenarai statik '
                    'terbenam (~8,200 domain pelupusan diketahui) tetap '
                    'berkuat kuasa walau senarai ini kosong.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = rows[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: const Icon(Icons.block_outlined),
                  title: Text(d.domain),
                  subtitle: Text('Ditambah ${relativeTime(d.createdAt)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Buang sekatan',
                    onPressed: () => _remove(context, ref, d),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DomainForm extends StatefulWidget {
  const _DomainForm({super.key});

  @override
  State<_DomainForm> createState() => _DomainFormState();
}

class _DomainFormState extends State<_DomainForm> {
  final _domain = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _domain.dispose();
    super.dispose();
  }

  void submit() {
    final domain = _domain.text.trim().toLowerCase();
    if (domain.isEmpty) {
      setState(() => _error = 'Domain diperlukan.');
      return;
    }
    Navigator.of(context).pop(domain);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDialogTextField(
          controller: _domain,
          label: 'Domain',
          hint: 'cth: contoh-pelupusan.com',
          autofocus: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
