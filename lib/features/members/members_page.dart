import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/app_action_sheet.dart';
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
);

/// Bottom sheet pilih role baru (Stage 12) — cuma papar role dengan rank
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
  // boleh jadi cuma role semasa ahli tu (cth supervisor edit ahli — satu
  // pilihan sahaja, itu pun yang dia dah ada). Elak bottom sheet kosong
  // yang buntu.
  if (assignable.every((r) => r.key == row.roleKey)) {
    MySnackBar.error(context, 'Tiada role lain yang boleh anda tetapkan.');
    return;
  }
  // Sheet yang sama dengan tindakan post/comment — mod pemilih (isSelected
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

class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider);
    final myRoleRank = ref.watch(myProfileProvider).valueOrNull?.roleRank ?? 0;

    // Await refresh betul-betul sampai data baru sedia, bukan sekadar
    // trigger invalidate — kalau tidak, spinner RefreshIndicator hilang
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: canEdit
          ? () => _showEditRoleSheet(context, ref, row, myRoleRank)
          : null,
      leading: MemberAvatar(
        label: row.displayName ?? row.memberId,
        avatarUrl: row.avatarUrl,
      ),
      title: Text(row.displayName ?? '(Tiada nama)'),
      // Emel cuma ada untuk management (dan baris sendiri) — jangan
      // tinggalkan baris kedua kosong bila ia disembunyikan.
      subtitle: Text(
        row.email == null ? row.memberId : '${row.memberId}\n${row.email}',
      ),
      isThreeLine: row.email != null,
      trailing: isManagement
          ? Chip(
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
            )
          : null,
    );
  }
}
