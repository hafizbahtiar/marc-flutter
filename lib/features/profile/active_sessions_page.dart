import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/profile/session_providers.dart';
import 'package:marc/shared/relative_time.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

final _placeholderSession = SessionRow(
  id: '00000000-0000-0000-0000-000000000000',
  userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)',
  createdIp: '203.0.113.7',
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026, 2),
);

/// Senarai sesi log masuk aktif + "log keluar device ni".
///
/// Sengaja TIADA penanda "sesi semasa" - lihat nota `SessionRow` di
/// `session_providers.dart`: backend tak boleh tentukannya daripada
/// access token, dan meneka akan mengelirukan (ahli log keluar device
/// salah). Untuk "log keluar SEMUA", butang log keluar biasa di Tetapan
/// kekal jalan yang betul.
class ActiveSessionsPage extends ConsumerWidget {
  const ActiveSessionsPage({super.key});

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    SessionRow row,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Log keluar sesi',
      message: 'Log keluar device ini? Device tersebut perlu log masuk semula.',
      confirmLabel: 'Log keluar',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await ref.read(sessionRepositoryProvider).revoke(row.id);
      if (context.mounted) MySnackBar.success(context, 'Sesi dilog keluar.');
    } catch (e) {
      if (context.mounted) {
        MySnackBar.error(
          context,
          e is DioException ? extractErrorMessage(e) : 'Gagal log keluar sesi.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);

    Future<void> onRefresh() => ref.refresh(sessionsProvider.future);

    return Scaffold(
      appBar: AppBar(title: const Text('Sesi Aktif')),
      body: SafeArea(
        child: sessions.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: _SessionList(
              rows: List.filled(3, _placeholderSession),
              onRevoke: (_) {},
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
                        'Gagal memuat senarai sesi.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(sessionsProvider),
                        child: const Text('Cuba lagi'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          data: (rows) => RefreshIndicator.adaptive(
            onRefresh: onRefresh,
            child: ListView(
              children: [
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: Text('Tiada sesi aktif.')),
                  )
                else
                  _SessionList(
                    rows: rows,
                    onRevoke: (row) => _revoke(context, ref, row),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Text(
                    'Setiap baris ialah satu log masuk. Log keluar sesi yang '
                    'anda tak cam.',
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

class _SessionList extends StatelessWidget {
  const _SessionList({required this.rows, required this.onRevoke});

  final List<SessionRow> rows;
  final void Function(SessionRow row) onRevoke;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) =>
          _SessionTile(row: rows[i], onRevoke: () => onRevoke(rows[i])),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.row, required this.onRevoke});

  final SessionRow row;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    // Sesi lama (sebelum backend rakam metadata) tiada user_agent/ip -
    // papar "Tidak diketahui", jangan sembunyikan barisnya: ia tetap
    // sesi hidup yang ahli patut boleh log keluar.
    final ua = row.userAgent?.isNotEmpty == true
        ? row.userAgent!
        : 'Peranti tidak diketahui';
    final ip = row.createdIp?.isNotEmpty == true
        ? row.createdIp!
        : 'IP tidak diketahui';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: const Icon(Icons.devices_outlined),
      title: Text(ua),
      subtitle: Text('$ip · ${relativeTime(row.createdAt)}'),
      isThreeLine: true,
      trailing: IconButton(
        icon: const Icon(Icons.logout),
        tooltip: 'Log keluar',
        onPressed: onRevoke,
      ),
    );
  }
}
