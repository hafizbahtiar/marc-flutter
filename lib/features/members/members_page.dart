import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/profile/profile_providers.dart';

const _placeholderRow = MemberRow(
  memberId: 'MARC2026/08/0000',
  displayName: 'Nama Ahli',
  roleName: 'Ahli',
  category: 'ahli',
);

class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider);

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
            child: _MemberList(rows: List.filled(6, _placeholderRow)),
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
              child: _MemberList(rows: rows),
            );
          },
        ),
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({required this.rows});

  final List<MemberRow> rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _MemberTile(row: rows[i]),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.row});

  final MemberRow row;

  @override
  Widget build(BuildContext context) {
    final isManagement = row.category == 'management';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
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
      subtitle: Text(row.memberId),
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
