import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/features/activities/manage/management_gate.dart';
import 'package:marc/features/admin/account_deletions_models.dart';
import 'package:marc/features/admin/account_deletions_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';
import 'package:marc/shared/ui/dialog/confirm_dialog.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

class AccountDeletionsPage extends ConsumerWidget {
  const AccountDeletionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ManagementGate(
      title: 'Pemadaman Akaun',
      child: ref.watch(isSuperAdminProvider)
          ? const _AccountDeletionsBody()
          : const Scaffold(
              appBar: _AccountDeletionAppBar(),
              body: Center(child: Text('Skrin ini untuk superadmin sahaja.')),
            ),
    );
  }
}

class _AccountDeletionAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _AccountDeletionAppBar();

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Pemadaman Akaun'));

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AccountDeletionsBody extends ConsumerWidget {
  const _AccountDeletionsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountDeletionProvider);
    return Scaffold(
      appBar: const _AccountDeletionAppBar(),
      body: SafeArea(
        child: state.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => _ErrorView(
            message: 'Gagal memuat senarai pemadaman.',
            retry: () => ref.invalidate(accountDeletionProvider),
          ),
          data: (data) => DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Permintaan ahli'),
                    Tab(text: 'Pemadaman pentadbiran'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _DeletionList(rows: data.requests, isRequest: true),
                      _DeletionList(rows: data.targets, isRequest: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeletionList extends ConsumerWidget {
  const _DeletionList({required this.rows, required this.isRequest});

  final List<AccountDeletionRow> rows;
  final bool isRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => ref.invalidate(accountDeletionProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  isRequest
                      ? 'Tiada permintaan pemadaman ahli.'
                      : 'Tiada akaun untuk pemadaman pentadbiran.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(accountDeletionProvider),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) =>
            _DeletionTile(row: rows[index], isRequest: isRequest),
      ),
    );
  }
}

class _DeletionTile extends ConsumerWidget {
  const _DeletionTile({required this.row, required this.isRequest});

  final AccountDeletionRow row;
  final bool isRequest;

  Future<void> _execute(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: isRequest ? 'Proses permintaan' : 'Padam akaun',
      message: isRequest
          ? 'Akaun ${row.email} dan data berkaitan akan dipadam secara kekal.'
          : 'Akaun ${row.email} akan dipadam secara pentadbiran.',
      confirmLabel: 'Teruskan',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    String? reason;
    if (!isRequest) {
      reason = await showAppInputDialog(
        context,
        title: 'Sebab pemadaman',
        message: 'Sebab ini akan direkodkan dalam audit.',
        positiveLabel: 'Simpan sebab',
        hint: 'Sebab',
        maxLength: 500,
        maxLines: 3,
        isDestructive: true,
      );
      if (reason == null || reason.trim().isEmpty || !context.mounted) return;
    }

    final error = isRequest
        ? await ref
              .read(accountDeletionRepositoryProvider)
              .executeRequest(row.userId)
        : await ref
              .read(accountDeletionRepositoryProvider)
              .executeDirect(row.userId, reason!.trim());
    if (!context.mounted) return;
    if (error == null) {
      MySnackBar.success(context, 'Pemadaman akaun berjaya diproses.');
    } else {
      MySnackBar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = row.displayName?.trim().isNotEmpty == true
        ? row.displayName!
        : 'Tanpa nama';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      title: Text(name),
      subtitle: Text(
        '${row.email}\n${row.memberId ?? "No. ahli belum dijana"} · '
        '${_formatDate(row.requestedAt)}',
      ),
      isThreeLine: true,
      trailing: FilledButton.tonal(
        onPressed: () => _execute(context, ref),
        child: Text(isRequest ? 'Proses' : 'Padam'),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: const Text('Cuba lagi')),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} '
      '${local.hour}:$minute';
}
