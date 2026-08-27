import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/profile/address_providers.dart';
import 'package:marc/shared/ui/sheet/app_action_sheet.dart';
import 'package:marc/shared/ui/dialog/confirm_dialog.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

final _placeholderAddress = AddressRow(
  id: '00000000-0000-0000-0000-000000000000',
  isDefault: true,
  addressType: 'landed',
  unitNumber: 'No. 12',
  street: 'Jalan Contoh 1',
  township: 'Taman Contoh',
  city: 'Shah Alam',
  postcode: '40000',
  state: 'Selangor',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

enum _AddressAction { edit, setDefault, delete }

class ManageAddressesPage extends ConsumerWidget {
  const ManageAddressesPage({super.key});

  Future<void> _openActions(
    BuildContext context,
    WidgetRef ref,
    AddressRow row,
  ) async {
    final action = await showAppActionSheet<_AddressAction>(
      context,
      title: row.label?.isNotEmpty == true
          ? row.label!
          : (row.summary.isEmpty ? row.cityLine : row.summary),
      actions: [
        const AppSheetAction(
          value: _AddressAction.edit,
          label: 'Edit',
          icon: Icons.edit_outlined,
        ),
        if (!row.isDefault)
          const AppSheetAction(
            value: _AddressAction.setDefault,
            label: 'Jadikan alamat utama',
            icon: Icons.star_outline,
          ),
        const AppSheetAction(
          value: _AddressAction.delete,
          label: 'Padam',
          icon: Icons.delete_outline,
          isDestructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _AddressAction.edit:
        context.push('/profile/addresses/${row.id}/edit', extra: row);
      case _AddressAction.setDefault:
        await _setDefault(context, ref, row);
      case _AddressAction.delete:
        await _delete(context, ref, row);
    }
  }

  Future<void> _setDefault(
    BuildContext context,
    WidgetRef ref,
    AddressRow row,
  ) async {
    try {
      await ref.read(addressRepositoryProvider).update(row.id, isDefault: true);
      if (context.mounted) MySnackBar.success(context, 'Alamat utama dikemas kini.');
    } catch (e) {
      if (context.mounted) {
        MySnackBar.error(
          context,
          e is DioException
              ? extractErrorMessage(e)
              : 'Gagal kemas kini alamat utama.',
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, AddressRow row) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Padam alamat',
      message: 'Padam alamat ini? Tindakan ini tidak boleh dibatalkan.',
      confirmLabel: 'Padam',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await ref.read(addressRepositoryProvider).delete(row.id);
      if (context.mounted) MySnackBar.success(context, 'Alamat dipadam.');
    } catch (e) {
      if (context.mounted) {
        MySnackBar.error(
          context,
          e is DioException ? extractErrorMessage(e) : 'Gagal padam alamat.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);

    Future<void> onRefresh() => ref.refresh(addressesProvider.future);

    return Scaffold(
      appBar: AppBar(title: const Text('Alamat Saya')),
      body: SafeArea(
        child: addresses.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: _AddressList(rows: List.filled(2, _placeholderAddress), onTap: (_) {}),
          ),
          error: (e, _) => RefreshIndicator.adaptive(
            onRefresh: onRefresh,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 80,
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Gagal memuat senarai alamat.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(addressesProvider),
                        child: const Text('Cuba lagi'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          data: (rows) {
            return RefreshIndicator.adaptive(
              onRefresh: onRefresh,
              child: ListView(
                children: [
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: Text('Tiada alamat disimpan.')),
                    )
                  else
                    _AddressList(
                      rows: rows,
                      onTap: (row) => _openActions(context, ref, row),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Text(
                      '${rows.length}/$kMaxAddresses alamat digunakan.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: FilledButton.icon(
                      onPressed: rows.length >= kMaxAddresses
                          ? null
                          : () => context.push('/profile/addresses/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Alamat'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AddressList extends StatelessWidget {
  const _AddressList({required this.rows, required this.onTap});

  final List<AddressRow> rows;
  final void Function(AddressRow row) onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _AddressTile(
        row: rows[i],
        onTap: () => onTap(rows[i]),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.row, required this.onTap});

  final AddressRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: onTap,
      title: Text(
        row.label?.isNotEmpty == true
            ? row.label!
            : (row.summary.isEmpty ? row.cityLine : row.summary),
      ),
      subtitle: Text(
        row.summary.isEmpty ? row.cityLine : '${row.summary}\n${row.cityLine}',
      ),
      isThreeLine: row.summary.isNotEmpty,
      trailing: row.isDefault
          ? Chip(
              label: const Text('Default'),
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                color: Theme.of(context).extension<AppSemanticColors>()!.accentDark,
                fontSize: 12,
              ),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            )
          : null,
    );
  }
}
