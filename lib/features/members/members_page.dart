import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc_flutter/app/theme.dart';
import 'package:marc_flutter/features/profile/profile_providers.dart';

class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ahli')),
      body: SafeArea(
        child: members.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Gagal memuat senarai ahli.\n$e',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const Center(child: Text('Tiada ahli.'));
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(membersProvider),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _MemberTile(row: rows[i]),
              ),
            );
          },
        ),
      ),
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
