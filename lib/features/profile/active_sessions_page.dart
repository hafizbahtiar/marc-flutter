import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/profile/session_providers.dart';
import 'package:marc/shared/utils/relative_time.dart';
import 'package:marc/shared/ui/dialog/confirm_dialog.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

final _placeholderSession = SessionRow(
  id: '00000000-0000-0000-0000-000000000000',
  userAgent: 'iPhone Hafiz - iOS 18.0',
  createdIp: '203.0.113.7',
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026, 2),
);

/// Senarai sesi log masuk aktif + log keluar per device atau beramai-ramai.
///
/// "Peranti ini" datang dari `is_current` backend (claim `sid` dalam
/// access token = family_id). Bukan tekaan "paling baharu".
class ActiveSessionsPage extends ConsumerStatefulWidget {
  const ActiveSessionsPage({super.key});

  @override
  ConsumerState<ActiveSessionsPage> createState() => _ActiveSessionsPageState();
}

class _ActiveSessionsPageState extends ConsumerState<ActiveSessionsPage> {
  bool _selectionMode = false;
  final _selectedIds = <String>{};

  void _enterSelectionMode() => setState(() => _selectionMode = true);

  void _exitSelectionMode() => setState(() {
    _selectionMode = false;
    _selectedIds.clear();
  });

  void _toggleRow(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectionMode = true;
        _selectedIds.add(id);
      }
    });
  }

  void _startSelectionWith(SessionRow row) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(row.id);
    });
  }

  void _selectAll(List<SessionRow> rows) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(rows.map((r) => r.id));
    });
  }

  Future<void> _revokeOne(SessionRow row) async {
    final ok = await showConfirmDialog(
      context,
      title: row.isCurrent ? 'Log keluar peranti ini' : 'Log keluar sesi',
      message: row.isCurrent
          ? 'Anda akan dikembalikan ke skrin log masuk.'
          : 'Log keluar device ini? Device tersebut perlu log masuk semula.',
      confirmLabel: 'Log keluar',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    try {
      await ref.read(sessionRepositoryProvider).revoke(row.id);
      if (!mounted) return;
      if (row.isCurrent) {
        await ref.read(authServiceProvider).signOut();
        return;
      }
      MySnackBar.success(context, 'Sesi dilog keluar.');
    } catch (e) {
      if (mounted) {
        MySnackBar.error(
          context,
          e is DioException ? extractErrorMessage(e) : 'Gagal log keluar sesi.',
        );
      }
    }
  }

  Future<void> _revokeSelected() async {
    if (_selectedIds.isEmpty) return;
    final rows = ref.read(sessionsProvider).valueOrNull ?? const <SessionRow>[];
    final includesCurrent = rows.any(
      (r) => r.isCurrent && _selectedIds.contains(r.id),
    );
    final count = _selectedIds.length;
    final ok = await showConfirmDialog(
      context,
      title: includesCurrent ? 'Log keluar sesi' : 'Log keluar sesi',
      message: includesCurrent
          ? 'Pilihan termasuk peranti ini. Anda akan dikembalikan ke skrin log masuk.'
          : count == 1
          ? 'Log keluar device ini? Device tersebut perlu log masuk semula.'
          : 'Log keluar $count device? Semua device terpilih perlu log masuk semula.',
      confirmLabel: count == 1 ? 'Log keluar' : 'Log keluar ($count)',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    final ids = _selectedIds.toList(growable: false);
    try {
      await ref.read(sessionRepositoryProvider).revokeMany(ids);
      if (!mounted) return;
      if (includesCurrent) {
        await ref.read(authServiceProvider).signOut();
        return;
      }
      _exitSelectionMode();
      MySnackBar.success(
        context,
        count == 1 ? 'Sesi dilog keluar.' : '$count sesi dilog keluar.',
      );
    } catch (e) {
      if (mounted) {
        MySnackBar.error(
          context,
          e is DioException ? extractErrorMessage(e) : 'Gagal log keluar sesi.',
        );
      }
    }
  }

  PreferredSizeWidget _appBar(List<SessionRow> rows) {
    if (!_selectionMode) {
      return AppBar(
        title: const Text('Sesi Aktif'),
        actions: [
          if (rows.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Pilih sesi',
              onPressed: _enterSelectionMode,
            ),
        ],
      );
    }

    final allSelected = rows.isNotEmpty && _selectedIds.length == rows.length;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Batal',
        onPressed: _exitSelectionMode,
      ),
      title: Text('${_selectedIds.length} dipilih'),
      actions: [
        TextButton(
          onPressed: rows.isEmpty
              ? null
              : () {
                  if (allSelected) {
                    setState(_selectedIds.clear);
                  } else {
                    _selectAll(rows);
                  }
                },
          child: Text(allSelected ? 'Nyahpilih semua' : 'Pilih semua'),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Log keluar terpilih',
          onPressed: _selectedIds.isEmpty ? null : _revokeSelected,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);

    Future<void> onRefresh() => ref.refresh(sessionsProvider.future);

    return Scaffold(
      appBar: sessions.maybeWhen(
        data: (rows) => _appBar(rows),
        orElse: () => AppBar(title: const Text('Sesi Aktif')),
      ),
      body: SafeArea(
        child: sessions.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: _SessionList(
              rows: List.filled(3, _placeholderSession),
              selectionMode: false,
              selectedIds: const {},
              onToggle: (_) {},
              onLongPress: (_) {},
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
                    selectionMode: _selectionMode,
                    selectedIds: _selectedIds,
                    onToggle: _toggleRow,
                    onLongPress: _startSelectionWith,
                    onRevoke: _revokeOne,
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
  const _SessionList({
    required this.rows,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggle,
    required this.onLongPress,
    required this.onRevoke,
  });

  final List<SessionRow> rows;
  final bool selectionMode;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;
  final void Function(SessionRow row) onLongPress;
  final void Function(SessionRow row) onRevoke;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _SessionTile(
        row: rows[i],
        selectionMode: selectionMode,
        selected: selectedIds.contains(rows[i].id),
        onToggle: () => onToggle(rows[i].id),
        onLongPress: () => onLongPress(rows[i]),
        onRevoke: () => onRevoke(rows[i]),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.row,
    required this.selectionMode,
    required this.selected,
    required this.onToggle,
    required this.onLongPress,
    required this.onRevoke,
  });

  final SessionRow row;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    // Sesi lama (sebelum backend rakam metadata) tiada user_agent/ip -
    // papar "Tidak diketahui", jangan sembunyikan barisnya: ia tetap
    // sesi hidup yang ahli patut boleh log keluar.
    final device = row.userAgent?.isNotEmpty == true
        ? row.userAgent!
        : 'Peranti tidak diketahui';
    final ip = row.createdIp?.isNotEmpty == true
        ? row.createdIp!
        : 'IP tidak diketahui';
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onToggle())
          : Icon(
              row.isCurrent ? Icons.smartphone : Icons.devices_outlined,
              color: row.isCurrent ? scheme.primary : null,
            ),
      title: Text(device),
      subtitle: Text(
        [
          if (row.isCurrent) 'Peranti ini',
          '$ip · ${relativeTime(row.createdAt)}',
        ].join(' · '),
      ),
      isThreeLine: true,
      trailing: selectionMode
          ? null
          : IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log keluar',
              onPressed: onRevoke,
            ),
      onTap: selectionMode ? onToggle : null,
      onLongPress: selectionMode ? null : onLongPress,
    );
  }
}
