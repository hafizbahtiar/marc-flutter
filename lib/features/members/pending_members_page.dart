import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';
import 'package:skeletonizer/skeletonizer.dart';

const _placeholderPendingRow = MemberRow(
  userId: '00000000-0000-0000-0000-000000000000',
  memberId: 'MARC2026/08/0000',
  displayName: 'Nama Ahli',
  roleName: 'Ahli',
  category: 'ahli',
  status: 'pending',
);

class PendingMembersPage extends ConsumerWidget {
  const PendingMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isManagement =
        ref.watch(myProfileProvider).valueOrNull?.isManagement ?? false;
    if (!isManagement) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ahli Pending')),
        body: const SafeArea(
          child: Center(child: Text('Anda tiada akses ke skrin ini.')),
        ),
      );
    }

    final pending = ref.watch(pendingMembersProvider);

    Future<void> onRefresh() => ref.refresh(pendingMembersProvider.future);

    Future<void> handleApprove(MemberRow row) async {
      try {
        await ref.read(profileRepositoryProvider).approveMember(row.userId);
        if (context.mounted) {
          MySnackBar.success(context, '${row.memberId} diluluskan.');
        }
      } catch (_) {
        if (context.mounted) {
          MySnackBar.error(context, 'Gagal luluskan ahli.');
        }
      }
    }

    Future<void> handleReject(MemberRow row) async {
      try {
        await ref.read(profileRepositoryProvider).rejectMember(row.userId);
        if (context.mounted) {
          MySnackBar.success(context, '${row.memberId} ditolak.');
        }
      } catch (_) {
        if (context.mounted) {
          MySnackBar.error(context, 'Gagal tolak ahli.');
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ahli Pending')),
      body: SafeArea(
        child: pending.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: _PendingList(
              rows: List.filled(4, _placeholderPendingRow),
              onApprove: (_) {},
              onReject: (_) {},
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
                        'Gagal memuat senarai ahli pending.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(pendingMembersProvider),
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
                      child: Center(
                        child: Text('Tiada ahli menunggu kelulusan.'),
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator.adaptive(
              onRefresh: onRefresh,
              child: _PendingList(
                rows: rows,
                onApprove: handleApprove,
                onReject: handleReject,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PendingList extends StatelessWidget {
  const _PendingList({
    required this.rows,
    required this.onApprove,
    required this.onReject,
  });

  final List<MemberRow> rows;
  final void Function(MemberRow row) onApprove;
  final void Function(MemberRow row) onReject;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _PendingTile(
        row: rows[i],
        onApprove: () => onApprove(rows[i]),
        onReject: () => onReject(rows[i]),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.row,
    required this.onApprove,
    required this.onReject,
  });

  final MemberRow row;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.fieldFill,
            child: Text(
              (row.displayName?.isNotEmpty ?? false)
                  ? row.displayName![0].toUpperCase()
                  : '?',
              style: const TextStyle(color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.displayName ?? '(Tiada nama)'),
                Text(
                  row.memberId,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.check_circle_outline,
              color: AppColors.accent,
            ),
            tooltip: 'Luluskan',
            onPressed: onApprove,
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
            tooltip: 'Tolak',
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}
