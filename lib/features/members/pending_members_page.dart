import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/profile/profile_providers.dart';
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
    required this.isAdminOrAbove,
  });

  final List<MemberRow> rows;
  final Future<void> Function(MemberRow row) onApprove;
  final Future<void> Function(MemberRow row) onReject;
  final Future<void> Function(MemberRow row) onApproveBypass;
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
    required this.isAdminOrAbove,
  });

  final MemberRow row;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;
  final Future<void> Function() onApproveBypass;
  final bool isAdminOrAbove;

  @override
  State<_PendingTile> createState() => _PendingTileState();
}

class _PendingTileState extends State<_PendingTile> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _name => widget.row.displayName ?? widget.row.memberId;

  /// Laluan biasa — ahli dah bayar yuran dalam sistem.
  bool get _canApproveNormally =>
      widget.row.registrationPaymentStatus == 'succeeded';

  /// Laluan migrasi — admin/superadmin sahaja, ahli belum bayar online,
  /// TIADA bil ToyyibPay 'pending' yang masih hidup (backend 409 kalau ada).
  bool get _canBypass =>
      widget.isAdminOrAbove &&
      widget.row.registrationPaymentStatus != 'succeeded' &&
      widget.row.registrationPaymentStatus != 'pending';

  bool get _hasPendingOnlineBill =>
      widget.row.registrationPaymentStatus == 'pending';

  String get _approveTooltip {
    if (_canApproveNormally) return 'Luluskan';
    if (_hasPendingOnlineBill) {
      return 'Ahli ada bil online belum selesai — selesaikan bil tu dulu';
    }
    if (widget.isAdminOrAbove) {
      return 'Ahli belum bayar — guna butang langkau bayaran untuk ahli lama';
    }
    return 'Ahli belum bayar yuran — cuma admin/superadmin boleh langkau';
  }

  String get _bypassTooltip =>
      'Luluskan tanpa bayaran (ahli lama, bayar manual sebelum sistem digital)';

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

  // Dialog pengesahan + nota wajib dah dikendalikan oleh
  // `handleApproveBypass` (pending_members_page level) - di sini cuma
  // gilir `_busy` sekitarnya, sama pola dgn _confirmApprove/_confirmReject.
  Future<void> _approveBypass() async {
    await _run(widget.onApproveBypass);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          MemberAvatar(
            label: widget.row.displayName ?? widget.row.memberId,
            avatarUrl: widget.row.avatarUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.row.displayName ?? '(Tiada nama)'),
                Text(
                  widget.row.memberId,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                // Skrin ni management-sahaja, jadi emel sepatutnya sentiasa
                // ada - tapi jangan crash/papar "null" kalau backend
                // sembunyikannya.
                if (widget.row.email != null)
                  Text(
                    widget.row.email!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 4),
                _PaymentStatusBadge(
                  status: widget.row.registrationPaymentStatus,
                ),
                if (_hasPendingOnlineBill && widget.isAdminOrAbove)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Bil online masih aktif — selesaikan/tamatkan sebelum '
                      'langkau bayaran.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.extension<AppSemanticColors>()!.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_canBypass)
            IconButton(
              icon: Icon(
                Icons.money_off_outlined,
                color: theme.extension<AppSemanticColors>()!.warning,
              ),
              tooltip: _bypassTooltip,
              onPressed: _busy ? null : _approveBypass,
            ),
          IconButton(
            icon: Icon(Icons.check_circle_outline, color: scheme.primary),
            tooltip: _approveTooltip,
            onPressed: _busy || !_canApproveNormally ? null : _confirmApprove,
          ),
          IconButton(
            icon: Icon(Icons.cancel_outlined, color: scheme.error),
            tooltip: 'Tolak',
            onPressed: _busy ? null : _confirmReject,
          ),
        ],
      ),
    );
  }
}

/// Badge padat status yuran pendaftaran - versi ringkas
/// `_PaymentStatusChip` (feed_page.dart) untuk senarai, bukan skrin penuh.
/// Ditambah 2026-08-15 supaya management nampak siapa dah bayar SEBELUM
/// tekan Luluskan (server kekal hakim akhir - badge cuma isyarat, gate
/// `ApproveMember` sedia ada di backend).
class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge({required this.status});

  /// "pending"/"succeeded"/"failed", atau null kalau tak pernah cuba bayar.
  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label, color) = switch (status) {
      'succeeded' => (
        Icons.check_circle_outline,
        'Dibayar',
        theme.colorScheme.primary,
      ),
      'failed' => (
        Icons.error_outline,
        'Bayaran gagal',
        theme.colorScheme.error,
      ),
      'pending' => (
        Icons.hourglass_top,
        'Bil online belum selesai',
        theme.extension<AppSemanticColors>()!.warning,
      ),
      _ => (
        Icons.payments_outlined,
        'Belum bayar',
        theme.extension<AppSemanticColors>()!.warning,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}
