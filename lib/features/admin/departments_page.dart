import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/features/activities/manage/management_gate.dart';
import 'package:marc/features/admin/departments_models.dart';
import 'package:marc/features/admin/departments_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';
import 'package:marc/shared/ui/dialog/app_dialog_field.dart';
import 'package:marc/shared/ui/dialog/confirm_dialog.dart';
import 'package:marc/shared/ui/sheet/app_form_sheet.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

/// Skrin urus bahagian/jabatan organisasi (`departments`) - superadmin
/// SAHAJA, padanan corak & rasional `BlockedEmailDomainsPage` (root-level
/// config org-wide, bukan sekadar management umum).
class DepartmentsPage extends ConsumerWidget {
  const DepartmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ManagementGate(
      title: 'Bahagian/Jabatan',
      child: Consumer(
        builder: (context, ref, _) {
          final roles = ref.watch(rolesProvider);
          if (roles.isLoading) {
            return const Scaffold(
              appBar: _DepartmentsAppBar(),
              body: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          if (roles.hasError) {
            return Scaffold(
              appBar: const _DepartmentsAppBar(),
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
              appBar: _DepartmentsAppBar(),
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
          return const _DepartmentsBody();
        },
      ),
    );
  }
}

class _DepartmentsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _DepartmentsAppBar();

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Bahagian/Jabatan'));

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _DepartmentsBody extends ConsumerWidget {
  const _DepartmentsBody();

  Future<void> _openAdd(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<_DepartmentFormState>();
    final result = await showAppFormSheet<(String, String)>(
      context,
      title: 'Tambah Bahagian',
      content: _DepartmentForm(key: formKey),
      actions: (ctx) => [
        AppDialogAction(
          label: 'Batal',
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        AppDialogAction(
          label: 'Tambah',
          isPrimary: true,
          onPressed: () => formKey.currentState?.submit(),
        ),
      ],
    );
    if (result == null || !context.mounted) return;
    final (code, name) = result;

    final res = await ref
        .read(departmentsRepositoryProvider)
        .add(code: code, name: name);
    if (!context.mounted) return;
    if (res.isOk) {
      MySnackBar.success(context, 'Bahagian "$code" ditambah.');
    } else {
      MySnackBar.error(context, res.message ?? 'Gagal tambah bahagian.');
    }
  }

  Future<void> _openEdit(
    BuildContext context,
    WidgetRef ref,
    Department d,
  ) async {
    final formKey = GlobalKey<_DepartmentFormState>();
    final result = await showAppFormSheet<(String, String)>(
      context,
      title: 'Edit Bahagian',
      content: _DepartmentForm(key: formKey, existing: d),
      actions: (ctx) => [
        AppDialogAction(
          label: 'Batal',
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        AppDialogAction(
          label: 'Simpan',
          isPrimary: true,
          onPressed: () => formKey.currentState?.submit(),
        ),
      ],
    );
    if (result == null || !context.mounted) return;
    final (_, name) = result;

    final res = await ref
        .read(departmentsRepositoryProvider)
        .update(d.code, name: name);
    if (!context.mounted) return;
    if (!res.isOk) {
      MySnackBar.error(context, res.message ?? 'Gagal kemas kini bahagian.');
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Department d,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Buang bahagian',
      message: 'Buang "${d.code} - ${d.name}"?',
      confirmLabel: 'Buang',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    final res = await ref.read(departmentsRepositoryProvider).remove(d.code);
    if (!context.mounted) return;
    if (!res.isOk) {
      MySnackBar.error(context, res.message ?? 'Gagal buang bahagian.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments = ref.watch(departmentsProvider);

    return Scaffold(
      appBar: const _DepartmentsAppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: departments.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat senarai bahagian.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(departmentsProvider),
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
                  child: Text('Tiada bahagian direkod.'),
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
                  leading: const Icon(Icons.apartment_outlined),
                  title: Text(d.code),
                  subtitle: Text(d.name),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      if (action == 'edit') {
                        _openEdit(context, ref, d);
                      } else if (action == 'delete') {
                        _remove(context, ref, d);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Buang')),
                    ],
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

class _DepartmentForm extends StatefulWidget {
  const _DepartmentForm({super.key, this.existing});

  final Department? existing;

  @override
  State<_DepartmentForm> createState() => _DepartmentFormState();
}

class _DepartmentFormState extends State<_DepartmentForm> {
  late final _code = TextEditingController(text: widget.existing?.code ?? '');
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void submit() {
    final code = _code.text.trim();
    final name = _name.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() => _error = 'Kod dan nama diperlukan.');
      return;
    }
    Navigator.of(context).pop((code, name));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDialogTextField(
          controller: _code,
          label: 'Kod',
          hint: 'cth: BKP',
          enabled: !_isEdit,
          autofocus: !_isEdit,
        ),
        const SizedBox(height: 12),
        AppDialogTextField(
          controller: _name,
          label: 'Nama penuh',
          hint: 'cth: Bahagian Kewangan',
          autofocus: _isEdit,
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
