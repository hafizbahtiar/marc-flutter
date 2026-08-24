import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/activities/manage/manage_providers.dart';
import 'package:marc/features/admin/departments_models.dart';
import 'package:marc/features/admin/departments_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/app_action_sheet.dart';
import 'package:marc/shared/widgets/app_dialog.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';
import 'package:marc/shared/widgets/member_avatar.dart';

const _placeholderRow = MemberRow(
  userId: '00000000-0000-0000-0000-000000000000',
  memberId: 'MARC2026/08/0000',
  displayName: 'Nama Ahli',
  email: 'ahli@contoh.com',
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: 10,
  category: 'ahli',
  status: 'approved',
  isActive: true,
);

/// Gabung bahagian+jawatan jadi satu baris papar (cth "BKP · Penolong
/// Pegawai") - `null` kalau dua-dua kosong (elak baris subtitle kosong).
String? _deptPositionLine(MemberRow row) {
  final parts = [
    row.departmentCode,
    row.position,
  ].where((s) => s != null && s.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Sahkan & tukar status aktif/tak aktif ahli - management sahaja
/// (dipanggil bila [canEdit], gate rank hierarki sama macam tukar role).
Future<void> _confirmToggleActive(
  BuildContext context,
  WidgetRef ref,
  MemberRow row,
) async {
  final name = row.displayName ?? row.memberId;
  final makeActive = !row.isActive;
  final ok = await showConfirmDialog(
    context,
    title: makeActive ? 'Aktifkan ahli' : 'Nyahaktifkan ahli',
    message: makeActive
        ? 'Aktifkan semula $name?'
        : 'Nyahaktifkan $name? Status kelulusan pendaftaran tidak berubah.',
    confirmLabel: makeActive ? 'Aktifkan' : 'Nyahaktifkan',
    isDestructive: !makeActive,
  );
  if (!ok || !context.mounted) return;

  try {
    await ref
        .read(profileRepositoryProvider)
        .updateMemberActive(row.userId, makeActive);
    if (context.mounted) {
      MySnackBar.success(
        context,
        makeActive ? '$name diaktifkan.' : '$name dinyahaktifkan.',
      );
    }
  } catch (e) {
    if (context.mounted) {
      MySnackBar.error(
        context,
        e is DioException ? extractErrorMessage(e) : 'Gagal tukar status.',
      );
    }
  }
}

/// Bottom sheet pilih role baru (Stage 12) - cuma papar role dengan rank
/// lebih rendah drpd editor (backend kuatkuasakan semula, ni cuma UX
/// supaya pilihan yang bakal 403 tak ditunjuk terus).
Future<void> _showEditRoleSheet(
  BuildContext context,
  WidgetRef ref,
  MemberRow row,
  int myRoleRank,
) async {
  final roles = await ref.read(rolesProvider.future);
  final assignable = roles.where((r) => r.rank < myRoleRank).toList();

  if (!context.mounted) return;

  // Backend dah tapis /roles kepada rank bawah caller, jadi senarai ni
  // boleh jadi cuma role semasa ahli tu (cth supervisor edit ahli - satu
  // pilihan sahaja, itu pun yang dia dah ada). Elak bottom sheet kosong
  // yang buntu.
  if (assignable.every((r) => r.key == row.roleKey)) {
    MySnackBar.error(context, 'Tiada role lain yang boleh anda tetapkan.');
    return;
  }
  // Sheet yang sama dengan tindakan post/comment - mod pemilih (isSelected
  // papar tanda semak pada role semasa) dan bukan senarai tindakan.
  final selected = await showAppActionSheet<RoleOption>(
    context,
    title: 'Tukar role',
    message: row.displayName ?? row.memberId,
    actions: [
      for (final role in assignable)
        AppSheetAction(
          value: role,
          label: role.name,
          isSelected: role.key == row.roleKey,
        ),
    ],
  );

  if (selected == null || selected.key == row.roleKey) return;
  if (!context.mounted) return;

  try {
    await ref
        .read(profileRepositoryProvider)
        .updateMemberRole(row.userId, selected.key);
    if (context.mounted) {
      MySnackBar.success(
        context,
        'Role ${row.displayName ?? row.memberId} dikemas kini.',
      );
    }
  } catch (e) {
    if (context.mounted) {
      MySnackBar.error(
        context,
        e is DioException ? extractErrorMessage(e) : 'Gagal tukar role.',
      );
    }
  }
}

/// Borang pilih bahagian (dropdown, opsyenal "Tiada bahagian") + jawatan
/// (teks bebas). `key` diguna oleh pemanggil (`showAppDialog`) utk cetus
/// `submit()` dari butang "Simpan" di luar widget ni.
class _DepartmentPositionForm extends StatefulWidget {
  const _DepartmentPositionForm({
    super.key,
    required this.departments,
    this.initialDepartmentCode,
    this.initialPosition,
  });

  final List<Department> departments;
  final String? initialDepartmentCode;
  final String? initialPosition;

  @override
  State<_DepartmentPositionForm> createState() =>
      _DepartmentPositionFormState();
}

class _DepartmentPositionFormState extends State<_DepartmentPositionForm> {
  late String? _departmentCode = widget.initialDepartmentCode;
  late final _position = TextEditingController(
    text: widget.initialPosition ?? '',
  );

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void submit() {
    final position = _position.text.trim();
    Navigator.of(
      context,
    ).pop((_departmentCode, position.isEmpty ? null : position));
  }

  @override
  Widget build(BuildContext context) {
    // Backend `ListForAssignment` boleh pulangkan senarai yang dah tak
    // kandung kod semasa ahli (bahagian dibuang selepas ditetapkan) -
    // sisip sbg opsyen tambahan supaya dropdown tak crash/senyap reset.
    final codes = widget.departments.map((d) => d.code).toSet();
    final missingCurrent =
        _departmentCode != null && !codes.contains(_departmentCode);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _departmentCode,
          decoration: const InputDecoration(
            labelText: 'Bahagian',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tiada bahagian')),
            if (missingCurrent)
              DropdownMenuItem(
                value: _departmentCode,
                child: Text('$_departmentCode (tidak sah lagi)'),
              ),
            for (final d in widget.departments)
              DropdownMenuItem(value: d.code, child: Text('${d.code} - ${d.name}')),
          ],
          onChanged: (v) => setState(() => _departmentCode = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _position,
          maxLength: 150,
          decoration: const InputDecoration(
            labelText: 'Jawatan (cth: Penolong Pegawai)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

/// Buka borang tukar bahagian/jawatan seorang ahli - manager ke atas
/// SAHAJA (dipanggil bila [canEditDeptPosition]).
Future<void> _showEditDepartmentDialog(
  BuildContext context,
  WidgetRef ref,
  MemberRow row,
) async {
  final List<Department> departments;
  try {
    departments = await ref.read(assignableDepartmentsProvider.future);
  } catch (e) {
    if (context.mounted) {
      MySnackBar.error(
        context,
        e is DioException
            ? extractErrorMessage(e)
            : 'Gagal muat senarai bahagian.',
      );
    }
    return;
  }
  if (!context.mounted) return;

  final formKey = GlobalKey<_DepartmentPositionFormState>();
  final result = await showAppDialog<(String?, String?)>(
    context,
    title: 'Bahagian & Jawatan',
    content: _DepartmentPositionForm(
      key: formKey,
      departments: departments,
      initialDepartmentCode: row.departmentCode,
      initialPosition: row.position,
    ),
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
  final (departmentCode, position) = result;

  try {
    await ref
        .read(profileRepositoryProvider)
        .updateMemberDepartment(
          row.userId,
          departmentCode: departmentCode,
          position: position,
        );
    if (context.mounted) {
      MySnackBar.success(
        context,
        'Bahagian/jawatan ${row.displayName ?? row.memberId} dikemas kini.',
      );
    }
  } catch (e) {
    if (context.mounted) {
      MySnackBar.error(
        context,
        e is DioException
            ? extractErrorMessage(e)
            : 'Gagal kemas kini bahagian/jawatan.',
      );
    }
  }
}

enum _MemberAction { editRole, toggleActive, editDepartment }

/// Sheet tindakan management utk satu ahli. Tukar role/status aktif gate
/// `canEdit` (rank STRICTLY lebih tinggi); tukar bahagian/jawatan gate
/// [canEditDeptPosition] yang berasingan (manager ke atas, "setaraf & ke
/// bawah") - jadi hujah `canEdit` diperlukan supaya sheet tahu tindakan
/// mana nak papar.
Future<void> _showMemberActionsSheet(
  BuildContext context,
  WidgetRef ref,
  MemberRow row,
  int myRoleRank, {
  required bool canEdit,
  required bool canEditDeptPosition,
}) async {
  final action = await showAppActionSheet<_MemberAction>(
    context,
    title: row.displayName ?? row.memberId,
    message: row.memberId,
    actions: [
      if (canEdit) ...[
        const AppSheetAction(
          value: _MemberAction.editRole,
          label: 'Tukar role',
          icon: Icons.badge_outlined,
        ),
        AppSheetAction(
          value: _MemberAction.toggleActive,
          label: row.isActive ? 'Nyahaktifkan ahli' : 'Aktifkan ahli',
          icon: row.isActive
              ? Icons.person_off_outlined
              : Icons.person_outlined,
          isDestructive: row.isActive,
        ),
      ],
      if (canEditDeptPosition)
        const AppSheetAction(
          value: _MemberAction.editDepartment,
          label: 'Tukar bahagian & jawatan',
          icon: Icons.apartment_outlined,
        ),
    ],
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case _MemberAction.editRole:
      await _showEditRoleSheet(context, ref, row, myRoleRank);
    case _MemberAction.toggleActive:
      await _confirmToggleActive(context, ref, row);
    case _MemberAction.editDepartment:
      await _showEditDepartmentDialog(context, ref, row);
  }
}

class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider);
    final myRoleRank = ref.watch(myProfileProvider).valueOrNull?.roleRank ?? 0;

    // Await refresh betul-betul sampai data baru sedia, bukan sekadar
    // trigger invalidate - kalau tidak, spinner RefreshIndicator hilang
    // serta-merta sementara list flip ke skeleton (invalidate() pulang
    // segera, tak tunggu fetch baru siap).
    Future<void> onRefresh() => ref.refresh(membersProvider.future);

    return Scaffold(
      appBar: AppBar(title: const Text('Ahli')),
      body: SafeArea(
        child: members.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: _MemberList(
              rows: List.filled(6, _placeholderRow),
              myRoleRank: myRoleRank,
            ),
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
                        'Gagal memuat senarai ahli.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(membersProvider),
                        child: const Text('Cuba lagi'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return RefreshIndicator.adaptive(
                onRefresh: onRefresh,
                child: ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: Text('Tiada ahli.')),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator.adaptive(
              onRefresh: onRefresh,
              child: _MemberList(rows: rows, myRoleRank: myRoleRank),
            );
          },
        ),
      ),
    );
  }
}

class _MemberList extends ConsumerWidget {
  const _MemberList({required this.rows, required this.myRoleRank});

  final List<MemberRow> rows;
  final int myRoleRank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _MemberTile(row: rows[i], myRoleRank: myRoleRank),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.row, required this.myRoleRank});

  final MemberRow row;
  final int myRoleRank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isManagement = row.category == 'management';
    final canEdit = myRoleRank > row.roleRank;
    // Bahagian/jawatan: manager ke atas, "setaraf & ke bawah" (>=) - BEZA
    // drpd [canEdit] (role/status aktif, strictly >). Isyarat tambahan
    // di luar `canEdit` supaya rakan setaraf (cth manager -> manager lain)
    // tetap boleh sentuh baris utk tindakan ni walau `canEdit` sendiri false.
    final canEditDeptPosition =
        ref.watch(isManagerOrAboveProvider) && myRoleRank >= row.roleRank;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: canEdit || canEditDeptPosition
          ? () => _showMemberActionsSheet(
              context,
              ref,
              row,
              myRoleRank,
              canEdit: canEdit,
              canEditDeptPosition: canEditDeptPosition,
            )
          : null,
      leading: MemberAvatar(
        label: row.displayName ?? row.memberId,
        avatarUrl: row.avatarUrl,
      ),
      title: Text(row.displayName ?? '(Tiada nama)'),
      // Emel cuma ada untuk management (dan baris sendiri) - jangan
      // tinggalkan baris kedua kosong bila ia disembunyikan. Bahagian/
      // jawatan (kalau ada) baris tambahan - digabung satu baris (bukan
      // dua) supaya senarai tak jadi terlalu tinggi bila kedua-duanya diisi.
      subtitle: Text(
        [
          row.email == null ? row.memberId : '${row.memberId}\n${row.email}',
          ?_deptPositionLine(row),
        ].join('\n'),
      ),
      isThreeLine: row.email != null || row.departmentCode != null || row.position != null,
      trailing: !isManagement && row.isActive
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ahli tak aktif - label minimal (bukan chip kedua), warna
                // error supaya senang dikesan management tanpa lagi satu
                // kad/chip yang menyesakkan baris.
                if (!row.isActive) ...[
                  Text(
                    'Tidak aktif',
                    style: TextStyle(color: scheme.error, fontSize: 12),
                  ),
                  if (isManagement) const SizedBox(width: 8),
                ],
                if (isManagement)
                  Chip(
                    label: Text(row.roleName),
                    backgroundColor: scheme.primary.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).extension<AppSemanticColors>()!.accentDark,
                      fontSize: 12,
                    ),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
    );
  }
}
