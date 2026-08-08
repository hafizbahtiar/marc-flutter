import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

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
  final selected = await showModalBottomSheet<RoleOption>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              'Tukar role ${row.displayName ?? row.memberId}',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          for (final role in assignable)
            ListTile(
              title: Text(role.name),
              trailing: role.key == row.roleKey
                  ? const Icon(Icons.check, color: AppColors.accent)
                  : null,
              onTap: () => Navigator.pop(ctx, role),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (selected == null || selected.key == row.roleKey) return;
  if (!context.mounted) return;

  try {
    await ref
        .read(profileRepositoryProvider)
        .updateMemberRole(row.userId, selected.key);
    if (context.mounted) {
      MySnackBar.success(context, 'Role ${row.displayName ?? row.memberId} dikemas kini.');
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
      appBar: AppBar(
        title: const Text('Ahli'),
        actions: [
          if (ref.watch(myProfileProvider).valueOrNull?.isManagement ?? false)
            IconButton(
              icon: const Icon(Icons.pending_actions_outlined),
              tooltip: 'Ahli Pending',
              onPressed: () => context.push('/members/pending'),
            ),
        ],
      ),
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
    final isManagement = row.category == 'management';
    final canEdit = myRoleRank > row.roleRank;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: canEdit
          ? () => _showEditRoleSheet(context, ref, row, myRoleRank)
          : null,
      leading: CircleAvatar(
        backgroundColor: AppColors.fieldFill,
        child: Text(
          (row.displayName?.isNotEmpty ?? false)
              ? row.displayName![0].toUpperCase()
              : '?',
          style: const TextStyle(color: AppColors.ink),
        ),
      ),
      title: Text(row.displayName ?? '(Tiada nama)'),
      subtitle: Text('${row.memberId}\n${row.email}'),
      isThreeLine: true,
      trailing: isManagement
          ? Chip(
              label: Text(row.roleName),
              backgroundColor: AppColors.accent.withValues(alpha: 0.12),
              labelStyle: const TextStyle(
                color: AppColors.accentDark,
                fontSize: 12,
              ),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            )
          : null,
    );
  }
}
