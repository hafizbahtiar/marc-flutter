import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/activities/manage/manage_providers.dart';
import 'package:marc/features/admin/departments_models.dart';
import 'package:marc/features/admin/departments_providers.dart';
import 'package:marc/features/members/member_detail_model.dart';
import 'package:marc/features/members/member_providers.dart';
import 'package:marc/features/profile/address_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/app_action_sheet.dart';
import 'package:marc/shared/widgets/app_dialog.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/image_viewer_page.dart';
import 'package:marc/shared/widgets/member_avatar.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

/// Sahkan & tukar status aktif/tak aktif ahli - management sahaja
/// (dipanggil bila [_showMemberActionsSheet.canEdit], gate rank hierarki
/// sama macam tukar role).
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

/// Bottom sheet pilih role baru - cuma papar role dengan rank lebih rendah
/// drpd editor (backend kuatkuasakan semula, ni cuma UX supaya pilihan
/// yang bakal 403 tak ditunjuk terus).
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
              DropdownMenuItem(
                value: d.code,
                child: Text('${d.code} - ${d.name}'),
              ),
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
/// SAHAJA (dipanggil bila `canEditDeptPosition`).
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
      AppDialogAction(label: 'Batal', onPressed: () => Navigator.of(ctx).pop()),
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

/// Sheet tindakan management utk satu ahli - dipindah dari `members_page.dart`
/// (dulu dicetus terus dari ketukan baris senarai; kini dari butang AppBar
/// skrin profil ini SAHAJA, lihat [MemberDetailPage]).
///
/// Tukar role/status aktif gate `canEdit` (rank STRICTLY lebih tinggi);
/// tukar bahagian/jawatan gate [canEditDeptPosition] yang berasingan
/// (manager ke atas, "setaraf & ke bawah") - jadi hujah `canEdit`
/// diperlukan supaya sheet tahu tindakan mana nak papar.
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

/// Bina [MemberRow] drpd [MemberDetail] - `_showMemberActionsSheet` (sheet
/// tindakan pengurusan sedia ada) dibina utk bentuk senarai `MemberRow`,
/// bukan `MemberDetail`; medan yang tiada makna di sheet (Tier 2/3 selain
/// email) tak diperlukan sheet tu, jadi penukaran ni cukup mudah -
/// `email`/`registrationPaymentStatus` cuma diteruskan apa adanya (null
/// kalau viewer tak layak, sheet ni tak papar/guna medan tu pun).
MemberRow _toMemberRow(MemberDetail d) => MemberRow(
  userId: d.userId,
  memberId: d.memberId,
  displayName: d.displayName,
  email: d.email,
  roleKey: d.roleKey,
  roleName: d.roleName,
  roleRank: d.roleRank,
  category: d.category,
  status: d.status,
  avatarUrl: d.avatarUrl,
  registrationPaymentStatus: d.registrationPaymentStatus,
  isActive: d.isActive,
  departmentCode: d.departmentCode,
  departmentName: d.departmentName,
  position: d.position,
);

String? _deptPositionLine(MemberDetail d) {
  final parts = [
    d.departmentCode,
    d.position,
  ].where((s) => s != null && s.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Skrin profil SATU ahli - view-only, tiga peringkat keterlihatan medan
/// (server-side, lihat [MemberDetail]). Untuk viewer dengan kebenaran
/// edit atas ahli ni, butang tindakan pengurusan (role/status/bahagian)
/// terpapar di AppBar.
class MemberDetailPage extends ConsumerWidget {
  const MemberDetailPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(memberDetailProvider(userId));
    final myRoleRank = ref.watch(myProfileProvider).valueOrNull?.roleRank ?? 0;
    final isManagerOrAbove = ref.watch(isManagerOrAboveProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Ahli'),
        actions: [
          if (detailAsync.valueOrNull case final detail?)
            Builder(
              builder: (context) {
                final canEdit = myRoleRank > detail.roleRank;
                final canEditDeptPosition =
                    isManagerOrAbove && myRoleRank >= detail.roleRank;
                if (!canEdit && !canEditDeptPosition) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Tindakan pengurusan',
                  onPressed: () => _showMemberActionsSheet(
                    context,
                    ref,
                    _toMemberRow(detail),
                    myRoleRank,
                    canEdit: canEdit,
                    canEditDeptPosition: canEditDeptPosition,
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => RefreshIndicator.adaptive(
            onRefresh: () => ref.refresh(memberDetailProvider(userId).future),
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
                        'Gagal memuat profil ahli.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () =>
                            ref.invalidate(memberDetailProvider(userId)),
                        child: const Text('Cuba lagi'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          data: (detail) => _MemberDetailBody(detail: detail),
        ),
      ),
    );
  }
}

class _MemberDetailBody extends StatelessWidget {
  const _MemberDetailBody({required this.detail});

  final MemberDetail detail;

  @override
  Widget build(BuildContext context) {
    // Kehadiran nilai (bukan role viewer) ITU sendiri keputusan kebenaran
    // - lihat komen [MemberDetail]. Jangan tambah pengiraan role di sini.
    final hasContactTier =
        detail.email != null ||
        detail.phone != null ||
        detail.registrationPaymentStatus != null;
    final hasEmergencyTier =
        detail.emergencyContactName != null ||
        detail.emergencyContactPhone != null ||
        detail.healthNotes != null ||
        detail.telegramLinked != null ||
        detail.telegramUsername != null;
    final hasAddressTier = detail.addresses != null;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _Header(detail: detail),
        if (hasContactTier) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          _SectionTitle('Kenalan'),
          if (detail.email != null)
            _InfoTile(Icons.email_outlined, 'Emel', detail.email!),
          if (detail.phone != null)
            _InfoTile(Icons.phone_outlined, 'Telefon', detail.phone!),
          if (detail.registrationPaymentStatus != null)
            _InfoTile(
              Icons.receipt_long_outlined,
              'Status bayaran pendaftaran',
              _paymentStatusLabel(detail.registrationPaymentStatus!),
            ),
        ],
        if (hasEmergencyTier) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          _SectionTitle('Kecemasan & Kesihatan'),
          if (detail.emergencyContactName != null)
            _InfoTile(
              Icons.contact_emergency_outlined,
              'Nama waris/kenalan kecemasan',
              detail.emergencyContactName!,
            ),
          if (detail.emergencyContactPhone != null)
            _InfoTile(
              Icons.phone_forwarded_outlined,
              'Telefon waris/kenalan kecemasan',
              detail.emergencyContactPhone!,
            ),
          if (detail.healthNotes != null)
            _InfoTile(
              Icons.health_and_safety_outlined,
              'Nota kesihatan',
              detail.healthNotes!,
            ),
          if (detail.telegramLinked != null)
            _InfoTile(
              Icons.telegram,
              'Telegram',
              detail.telegramLinked!
                  ? (detail.telegramUsername ?? 'Dipautkan')
                  : 'Tidak dipautkan',
            ),
        ],
        if (hasAddressTier) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          _SectionTitle('Alamat'),
          if (detail.addresses!.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text('Tiada alamat.'),
            )
          else
            for (final address in detail.addresses!) _AddressTile(row: address),
        ],
      ],
    );
  }

  String _paymentStatusLabel(String status) => switch (status) {
    'pending' => 'Belum selesai',
    'succeeded' => 'Berjaya',
    'failed' => 'Gagal',
    _ => status,
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final MemberDetail detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = detail.displayName ?? detail.memberId;
    final heroTag = 'avatar-member-${detail.userId}';
    final deptPositionLine = _deptPositionLine(detail);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          MemberAvatar(
            label: label,
            avatarUrl: detail.avatarUrl,
            radius: 44,
            heroTag: heroTag,
            onTap: detail.avatarUrl == null
                ? null
                : () => ImageViewerPage.open(
                    context,
                    urls: [detail.avatarUrl!],
                    initialIndex: 0,
                    heroTagBuilder: (_, _) => heroTag,
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            detail.displayName ?? '(Tiada nama)',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(detail.memberId, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(detail.roleName),
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
              if (deptPositionLine != null)
                // Ketuk chip - buka direktori ahli (`/members`) tertapis
                // kepada bahagian ni (`extra`, dibaca oleh `MembersPage`
                // sbg `initialDepartmentCode`). Cuma tappable bila
                // `departmentCode` wujud - `deptPositionLine` boleh
                // terbentuk drpd jawatan sahaja (tanpa kod bahagian),
                // dalam kes tu tiada apa nak ditapis jadi kekal `Chip`
                // biasa (tak boleh ketuk).
                detail.departmentCode != null
                    ? ActionChip(
                        label: Text(deptPositionLine),
                        backgroundColor: scheme.surfaceContainerHighest,
                        labelStyle: const TextStyle(fontSize: 12),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => context.push(
                          '/members',
                          extra: detail.departmentCode,
                        ),
                      )
                    : Chip(
                        label: Text(deptPositionLine),
                        backgroundColor: scheme.surfaceContainerHighest,
                        labelStyle: const TextStyle(fontSize: 12),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
              Chip(
                label: Text(detail.isActive ? 'Aktif' : 'Tidak aktif'),
                backgroundColor: detail.isActive
                    ? scheme.tertiary.withValues(alpha: 0.12)
                    : scheme.error.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  color: detail.isActive ? scheme.tertiary : scheme.error,
                  fontSize: 12,
                ),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

/// Tile alamat view-only - gaya sama dgn `manage_addresses_page.dart`
/// TANPA `onTap` (tiada aksi edit/padam, skrin ni tak mengubah alamat
/// sesiapa).
class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.row});

  final AddressRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
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
                color: Theme.of(
                  context,
                ).extension<AppSemanticColors>()!.accentDark,
                fontSize: 12,
              ),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            )
          : null,
    );
  }
}
