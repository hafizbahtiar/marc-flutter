import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/features/activities/activity_models.dart';
import 'package:marc/features/activities/manage/manage_providers.dart';
import 'package:marc/features/activities/manage/management_gate.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

/// Skrin CRUD kategori aktiviti - manager ke atas SAHAJA (bukan sekadar
/// pengurusan). Kategori ialah infrastruktur dikongsi SEMUA aktiviti, bukan
/// tindakan pengurusan harian (cth luluskan ahli/terbit aktiviti) yang
/// supervisor pun boleh buat - lihat `isManagerOrAboveProvider`.
///
/// Kategori TIDAK PERNAH dipadam terus (`category_id` di `activities` ialah
/// `on delete restrict`) - "padam" di sini bermakna nyahaktifkan
/// (`is_active = false`), yang menyembunyikannya drpd borang cipta aktiviti
/// tanpa memecahkan aktiviti sedia ada yang masih memetiknya.
class ActivityCategoriesPage extends ConsumerWidget {
  const ActivityCategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ManagementGate(
      title: 'Urus Kategori',
      child: Consumer(
        builder: (context, ref, _) {
          // `isManagerOrAboveProvider` bergantung pada `rolesProvider`
          // (panggilan `/roles` berasingan drpd `/me`) - ia jadi `false`
          // sama ada betul-betul bukan manager ATAU sekadar masih memuat/
          // gagal. `ManagementGate` cuma jaga keadaan `myProfileProvider`,
          // jadi keadaan `rolesProvider` mesti disemak SENDIRI di sini,
          // kalau tidak manager sebenar nampak "akses ditolak" yang tak
          // boleh dicuba semula setiap kali `/roles` perlahan/gagal.
          final roles = ref.watch(rolesProvider);
          if (roles.isLoading) {
            return const Scaffold(
              appBar: _CategoriesAppBar(),
              body: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          if (roles.hasError) {
            return Scaffold(
              appBar: const _CategoriesAppBar(),
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
          if (!ref.watch(isManagerOrAboveProvider)) {
            return const Scaffold(
              appBar: _CategoriesAppBar(),
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Skrin ini untuk manager ke atas sahaja.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          return const _CategoriesBody();
        },
      ),
    );
  }
}

class _CategoriesAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CategoriesAppBar();

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Urus Kategori'));

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CategoriesBody extends ConsumerWidget {
  const _CategoriesBody();

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<_CategoryFormState>();
    final result = await showAppDialog<_CategoryFormResult>(
      context,
      title: 'Kategori Baharu',
      content: _CategoryForm(key: formKey),
      actions: (ctx) => [
        AppDialogAction(
          label: 'Batal',
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        AppDialogAction(
          label: 'Cipta',
          isPrimary: true,
          onPressed: () => formKey.currentState?.submit(),
        ),
      ],
    );
    if (result == null || !context.mounted) return;

    final res = await ref
        .read(activityManageRepositoryProvider)
        .createCategory(
          key: result.key,
          name: result.name,
          sortOrder: result.sortOrder,
        );
    if (!context.mounted) return;
    if (res.isOk) {
      MySnackBar.success(context, 'Kategori "${result.name}" dicipta.');
    } else {
      MySnackBar.error(context, res.message ?? 'Gagal cipta kategori.');
    }
  }

  Future<void> _openEdit(
    BuildContext context,
    WidgetRef ref,
    ActivityCategory category,
  ) async {
    final formKey = GlobalKey<_CategoryFormState>();
    final result = await showAppDialog<_CategoryFormResult>(
      context,
      title: 'Sunting Kategori',
      content: _CategoryForm(key: formKey, existing: category),
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

    final res = await ref
        .read(activityManageRepositoryProvider)
        .updateCategory(
          category.id,
          name: result.name,
          sortOrder: result.sortOrder,
        );
    if (!context.mounted) return;
    if (res.isOk) {
      MySnackBar.success(context, 'Kategori dikemas kini.');
    } else {
      MySnackBar.error(context, res.message ?? 'Gagal kemas kini kategori.');
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    ActivityCategory category,
  ) async {
    final res = await ref
        .read(activityManageRepositoryProvider)
        .updateCategory(category.id, isActive: !category.isActive);
    if (!context.mounted) return;
    if (!res.isOk) {
      MySnackBar.error(context, res.message ?? 'Gagal kemas kini kategori.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allActivityCategoriesProvider);

    return Scaffold(
      appBar: const _CategoriesAppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreate(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: categories.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat senarai kategori.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        ref.invalidate(allActivityCategoriesProvider),
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const Center(child: Text('Tiada kategori.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final cat = rows[i];
                return ListTile(
                  title: Text(
                    cat.name,
                    style: cat.isActive
                        ? null
                        : TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                  ),
                  subtitle: Text('${cat.key} · susunan ${cat.sortOrder}'),
                  trailing: Switch.adaptive(
                    value: cat.isActive,
                    onChanged: (_) => _toggleActive(context, ref, cat),
                  ),
                  onTap: () => _openEdit(context, ref, cat),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Nilai borang cipta/sunting kategori. [key] hanya relevan semasa cipta -
/// medan itu dibekukan (disabled) semasa sunting kerana backend tolak
/// perubahannya.
class _CategoryFormResult {
  const _CategoryFormResult({
    required this.key,
    required this.name,
    required this.sortOrder,
  });

  final String key;
  final String name;
  final int sortOrder;
}

/// Kandungan dialog cipta/sunting - [existing] null bermakna mod cipta.
///
/// StatefulWidget memegang controller sendiri (padanan `_EditTextDialog`):
/// dialog Material/Cupertino animasi keluar beberapa frame selepas
/// `Navigator.pop`, jadi controller mesti hidup selagi widget hidup, bukan
/// dibuang serta-merta selepas `pop`.
class _CategoryForm extends StatefulWidget {
  const _CategoryForm({super.key, this.existing});

  final ActivityCategory? existing;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final TextEditingController _key = TextEditingController(
    text: widget.existing?.key ?? '',
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _sortOrder = TextEditingController(
    text: (widget.existing?.sortOrder ?? 0).toString(),
  );

  bool get _isEdit => widget.existing != null;

  String? _error;

  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  /// Dipanggil oleh butang "Cipta"/"Simpan" AppDialogAction menerusi
  /// `GlobalKey` (bukan `findAncestorStateOfType`: `content` ialah ANAK
  /// `ctx`, bukan moyangnya, jadi carian moyang tidak akan jumpa widget
  /// ini).
  void submit() {
    final key = _key.text.trim();
    final name = _name.text.trim();
    final sortOrder = int.tryParse(_sortOrder.text.trim()) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = 'Nama diperlukan.');
      return;
    }
    if (!_isEdit && key.isEmpty) {
      setState(() => _error = 'Kunci diperlukan.');
      return;
    }

    Navigator.of(
      context,
    ).pop(_CategoryFormResult(key: key, name: name, sortOrder: sortOrder));
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    Widget field(
      TextEditingController controller,
      String placeholder, {
      bool enabled = true,
      TextInputType? keyboardType,
    }) {
      if (isApple) {
        return CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          enabled: enabled,
          keyboardType: keyboardType,
        );
      }
      return TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: placeholder,
          border: const OutlineInputBorder(),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `key` dibekukan semasa sunting - padanan backend (lihat komen di
        // atas class), bukan cuma UI: PATCH tidak menghantar medan ini
        // langsung dalam mod sunting.
        field(_key, 'Kunci (cth: badminton)', enabled: !_isEdit),
        const SizedBox(height: 12),
        field(_name, 'Nama'),
        const SizedBox(height: 12),
        field(_sortOrder, 'Susunan', keyboardType: TextInputType.number),
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
