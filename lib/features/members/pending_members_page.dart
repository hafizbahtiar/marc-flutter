import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/app_action_sheet.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';
import 'package:marc/shared/widgets/member_avatar.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/edit_text_dialog.dart';
import 'package:skeletonizer/skeletonizer.dart';

const _placeholderPendingRow = MemberRow(
  userId: '00000000-0000-0000-0000-000000000000',
  memberId: 'MARC2026/08/0000',
  displayName: 'Nama Ahli',
  email: 'ahli@contoh.com',
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: 10,
  category: 'ahli',
  status: 'pending',
);

enum _PendingAction { approve, cancelBill, bypass, reject }

class PendingMembersPage extends ConsumerWidget {
  const PendingMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lihat komen sama dalam audit_page.dart - jangan tuduh pengguna
    // tiada akses sedangkan profil dia belum siap dimuat.
    final profileAsync = ref.watch(myProfileProvider);
    if (profileAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ahli Pending')),
        body: const SafeArea(
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      );
    }
    final isManagement = profileAsync.valueOrNull?.isManagement ?? false;
    if (!isManagement) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ahli Pending')),
        body: const SafeArea(
          child: Center(child: Text('Anda tiada akses ke skrin ini.')),
        ),
      );
    }

    final pending = ref.watch(pendingMembersProvider);
    final isAdminOrAbove = ref.watch(isAdminOrAboveProvider);

    Future<void> onRefresh() => ref.refresh(pendingMembersProvider.future);

    Future<void> handleApprove(MemberRow row, {String? bypassReason}) async {
      try {
        await ref
            .read(profileRepositoryProvider)
            .approveMember(row.userId, bypassReason: bypassReason);
        if (context.mounted) {
          MySnackBar.success(context, '${row.memberId} diluluskan.');
        }
      } catch (e) {
        if (context.mounted) {
          MySnackBar.error(
            context,
            e is DioException ? extractErrorMessage(e) : 'Gagal luluskan ahli.',
          );
        }
      }
    }

    // Ahli lama (migrasi manual->digital) yang dah bayar tunai sebelum
    // sistem ni wujud - admin/superadmin sahaja (server hakim sebenar,
    // ni cuma UI). Nota WAJIB - showEditTextDialog pulang null kalau
    // kosong, jadi guard `reason == null` di bawah dah cukup.
    Future<void> handleApproveBypass(MemberRow row) async {
      final name = row.displayName ?? row.memberId;
      final ok = await showConfirmDialog(
        context,
        title: 'Langkau bayaran yuran',
        message:
            'Luluskan $name TANPA bayaran yuran pendaftaran? '
            'Guna ni cuma untuk ahli lama yang dah bayar secara manual '
            'sebelum sistem digital.',
        confirmLabel: 'Teruskan',
      );
      if (!ok || !context.mounted) return;

      final reason = await showEditTextDialog(
        context,
        title: 'Nota (wajib)',
        initialValue: '',
        maxLines: 3,
        maxLength: 500,
      );
      if (reason == null || !context.mounted) return;

      await handleApprove(row, bypassReason: reason);
    }

    Future<void> handleCancelBill(MemberRow row) async {
      final name = row.displayName ?? row.memberId;
      final ok = await showConfirmDialog(
        context,
        title: 'Batalkan bil online',
        message:
            'Batalkan bil yuran pendaftaran $name yang masih aktif? '
            'Guna ni sebelum langkau bayaran untuk ahli lama. '
            'Bil juga tamat tempoh automatik ~30 minit.',
        confirmLabel: 'Batalkan',
        isDestructive: true,
      );
      if (!ok || !context.mounted) return;

      try {
        await ref
            .read(profileRepositoryProvider)
            .cancelRegistrationPayment(row.userId);
        if (context.mounted) {
          MySnackBar.success(context, 'Bil ${row.memberId} dibatalkan.');
        }
      } catch (e) {
        if (context.mounted) {
          MySnackBar.error(
            context,
            e is DioException ? extractErrorMessage(e) : 'Gagal batalkan bil.',
          );
        }
      }
    }

    Future<void> handleReject(MemberRow row) async {
      try {
        await ref.read(profileRepositoryProvider).rejectMember(row.userId);
        if (context.mounted) {
          MySnackBar.success(context, '${row.memberId} ditolak.');
        }
      } catch (e) {
        if (context.mounted) {
          MySnackBar.error(
            context,
            e is DioException ? extractErrorMessage(e) : 'Gagal tolak ahli.',
          );
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
              onApprove: (_) async {},
              onReject: (_) async {},
              onApproveBypass: (_) async {},
              onCancelBill: (_) async {},
              isAdminOrAbove: isAdminOrAbove,
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
                onApproveBypass: handleApproveBypass,
                onCancelBill: handleCancelBill,
                isAdminOrAbove: isAdminOrAbove,
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
    required this.onApproveBypass,
    required this.onCancelBill,
    required this.isAdminOrAbove,
  });

  final List<MemberRow> rows;
  final Future<void> Function(MemberRow row) onApprove;
  final Future<void> Function(MemberRow row) onReject;
  final Future<void> Function(MemberRow row) onApproveBypass;
  final Future<void> Function(MemberRow row) onCancelBill;
  final bool isAdminOrAbove;

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
        onApproveBypass: () => onApproveBypass(rows[i]),
        onCancelBill: () => onCancelBill(rows[i]),
        isAdminOrAbove: isAdminOrAbove,
      ),
    );
  }
}

class _PendingTile extends StatefulWidget {
  const _PendingTile({
    required this.row,
    required this.onApprove,
    required this.onReject,
    required this.onApproveBypass,
    required this.onCancelBill,
    required this.isAdminOrAbove,
  });

  final MemberRow row;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;
  final Future<void> Function() onApproveBypass;
  final Future<void> Function() onCancelBill;
  final bool isAdminOrAbove;

  @override
  State<_PendingTile> createState() => _PendingTileState();
}

class _PendingTileState extends State<_PendingTile> {
  bool _busy = false;

  String get _name => widget.row.displayName ?? widget.row.memberId;

  bool get _canApproveNormally =>
      widget.row.registrationPaymentStatus == 'succeeded';

  bool get _canBypass =>
      widget.isAdminOrAbove &&
      widget.row.registrationPaymentStatus != 'succeeded' &&
      widget.row.registrationPaymentStatus != 'pending';

  bool get _hasPendingOnlineBill =>
      widget.row.registrationPaymentStatus == 'pending';

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmApprove() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Luluskan ahli',
      message: 'Luluskan pendaftaran $_name?',
      confirmLabel: 'Luluskan',
    );
    if (ok && mounted) await _run(widget.onApprove);
  }

  Future<void> _confirmReject() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Tolak ahli',
      message:
          'Tolak pendaftaran $_name? Ini boleh diluluskan semula '
          'kemudian jika perlu.',
      confirmLabel: 'Tolak',
      isDestructive: true,
    );
    if (ok && mounted) await _run(widget.onReject);
  }

  Future<void> _handleAction(_PendingAction action) async {
    switch (action) {
      case _PendingAction.approve:
        await _confirmApprove();
      case _PendingAction.cancelBill:
        await _run(widget.onCancelBill);
      case _PendingAction.bypass:
        await _run(widget.onApproveBypass);
      case _PendingAction.reject:
        await _confirmReject();
    }
  }

  Future<void> _openActions() async {
    if (_busy) return;

    final actions = <AppSheetAction<_PendingAction>>[
      if (_canApproveNormally)
        const AppSheetAction(
          value: _PendingAction.approve,
          label: 'Luluskan',
          icon: Icons.check_circle_outline,
          subtitle: 'Yuran pendaftaran telah dibayar',
        ),
      if (_hasPendingOnlineBill && widget.isAdminOrAbove)
        const AppSheetAction(
          value: _PendingAction.cancelBill,
          label: 'Batalkan bil online',
          icon: Icons.link_off_outlined,
          subtitle: 'Bil ToyyibPay masih aktif (~30 min)',
          isDestructive: true,
        ),
      if (_canBypass)
        const AppSheetAction(
          value: _PendingAction.bypass,
          label: 'Langkau bayaran',
          icon: Icons.money_off_outlined,
          subtitle: 'Untuk ahli lama yang dah bayar manual',
        ),
      const AppSheetAction(
        value: _PendingAction.reject,
        label: 'Tolak pendaftaran',
        icon: Icons.cancel_outlined,
        isDestructive: true,
      ),
    ];

    final action = await showAppActionSheet<_PendingAction>(
      context,
      title: _name,
      message: widget.row.memberId,
      actions: actions,
    );
    if (action == null || !mounted) return;
    await _handleAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: _busy ? null : _openActions,
      leading: MemberAvatar(
        label: row.displayName ?? row.memberId,
        avatarUrl: row.avatarUrl,
      ),
      title: Text(row.displayName ?? '(Tiada nama)'),
      subtitle: Text(
        row.email == null ? row.memberId : '${row.memberId}\n${row.email}',
      ),
      isThreeLine: row.email != null,
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : _PaymentStatusChip(status: row.registrationPaymentStatus),
    );
  }
}

/// Chip status yuran - gaya sama dengan chip role dalam members_page.dart.
class _PaymentStatusChip extends StatelessWidget {
  const _PaymentStatusChip({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warning = theme.extension<AppSemanticColors>()!.warning;

    final (label, color) = switch (status) {
      'succeeded' => ('Dibayar', scheme.primary),
      'failed' => ('Gagal', scheme.error),
      'pending' => ('Bil aktif', warning),
      _ => ('Belum bayar', warning),
    };

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontSize: 12),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
