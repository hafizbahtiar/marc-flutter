import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/profile/profile_providers.dart';
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
  isActive: true,
);

/// Gabung bahagian+jawatan jadi satu baris papar (cth "BKP · Penolong
/// Pegawai") - `null` kalau dua-dua kosong (elak baris subtitle kosong).
String? _deptPositionLine(MemberRow row) {
  final parts = [
    row.departmentCode,
    row.position,
  ].where((s) => s != null && s.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' · ');
}

class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider);

    // Await refresh betul-betul sampai data baru sedia, bukan sekadar
    // trigger invalidate - kalau tidak, spinner RefreshIndicator hilang
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

/// Baris ahli - ketukan navigasi ke [MemberDetailPage] (`/members/:userId`)
/// utk SEMUA viewer (termasuk yang ada kebenaran edit) - skrin profil tu
/// sendiri yang papar butang tindakan pengurusan (AppBar) bila kebenaran
/// ada, bukan lagi ketukan baris terus buka sheet.
class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.row});

  final MemberRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isManagement = row.category == 'management';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: () => context.push('/members/${row.userId}'),
      leading: MemberAvatar(
        label: row.displayName ?? row.memberId,
        avatarUrl: row.avatarUrl,
      ),
      title: Text(row.displayName ?? '(Tiada nama)'),
      // Emel cuma ada untuk management (dan baris sendiri) - jangan
      // tinggalkan baris kedua kosong bila ia disembunyikan. Bahagian/
      // jawatan (kalau ada) baris tambahan - digabung satu baris (bukan
      // dua) supaya senarai tak jadi terlalu tinggi bila kedua-duanya diisi.
      subtitle: Text(
        [
          row.email == null ? row.memberId : '${row.memberId}\n${row.email}',
          ?_deptPositionLine(row),
        ].join('\n'),
      ),
      isThreeLine:
          row.email != null ||
          row.departmentCode != null ||
          row.position != null,
      trailing: !isManagement && row.isActive
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ahli tak aktif - label minimal (bukan chip kedua), warna
                // error supaya senang dikesan management tanpa lagi satu
                // kad/chip yang menyesakkan baris.
                if (!row.isActive) ...[
                  Text(
                    'Tidak aktif',
                    style: TextStyle(color: scheme.error, fontSize: 12),
                  ),
                  if (isManagement) const SizedBox(width: 8),
                ],
                if (isManagement)
                  Chip(
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
                  ),
              ],
            ),
    );
  }
}
