import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/ui/widgets/member_avatar.dart';

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

/// Satu bahagian unik (kod+nama) - diterbitkan drpd senarai ahli yang
/// SUDAH diambil (bukan panggilan API berasingan). `departmentsProvider`/
/// `assignableDepartmentsProvider` (lihat `departments_providers.dart`)
/// digate superadmin/manager sahaja - ahli biasa akan dapat senarai
/// kosong drpd kedua-duanya, jadi pemilih penapis di sini takkan
/// berfungsi utk majoriti viewer kalau ia bergantung pada salah satu
/// provider tu. Terbitan client-side ni berfungsi utk SEMUA viewer,
/// padanan arahan "tiada endpoint backend baru diperlukan".
class _DeptOption {
  const _DeptOption(this.code, this.name);

  final String code;
  final String name;
}

List<_DeptOption> _departmentsFrom(List<MemberRow> rows) {
  final byCode = <String, String>{};
  for (final row in rows) {
    final code = row.departmentCode;
    if (code == null) continue;
    byCode.putIfAbsent(code, () => row.departmentName ?? code);
  }
  final options =
      byCode.entries.map((e) => _DeptOption(e.key, e.value)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  return options;
}

/// Senarai/direktori ahli - carian (nama/no. ahli) + penapis bahagian,
/// dua-duanya ditapis client-side atas senarai yang SUDAH diambil oleh
/// [membersProvider] (backend dah kuatkuasa peraturan keterlihatan
/// server-side, tiada lagi fetch diperlukan di sini).
///
/// [initialDepartmentCode] - dihantar drpd chip bahagian di
/// `MemberDetailPage` (lihat router `/members`, `state.extra`) supaya
/// direktori terus papar tertapis kepada bahagian tu bila viewer ketuk
/// chip. `null` (lalai) = tiada penapis, sama macam sebelum ni.
class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key, this.initialDepartmentCode});

  final String? initialDepartmentCode;

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  final _searchController = TextEditingController();
  String _query = '';
  late String? _selectedDepartmentCode = widget.initialDepartmentCode;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MemberRow> _filter(List<MemberRow> rows) {
    return rows.where((row) {
      if (_selectedDepartmentCode != null &&
          row.departmentCode != _selectedDepartmentCode) {
        return false;
      }
      if (_query.isEmpty) return true;
      final name = row.displayName?.toLowerCase() ?? '';
      final memberId = row.memberId.toLowerCase();
      return name.contains(_query) || memberId.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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

            final departments = _departmentsFrom(rows);
            final filtered = _filter(rows);

            return Column(
              children: [
                _SearchAndFilterBar(
                  controller: _searchController,
                  departments: departments,
                  selectedCode: _selectedDepartmentCode,
                  onDepartmentSelected: (code) =>
                      setState(() => _selectedDepartmentCode = code),
                ),
                const Divider(height: 1),
                Expanded(
                  child: RefreshIndicator.adaptive(
                    onRefresh: onRefresh,
                    child: filtered.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 80),
                                child: Center(
                                  child: Text('Tiada ahli sepadan.'),
                                ),
                              ),
                            ],
                          )
                        : _MemberList(rows: filtered),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Carian (nama/no. ahli) + baris chip bahagian ("Semua" + satu chip
/// setiap bahagian yang wujud dlm senarai ahli semasa) - dua-dua penapis
/// digabung dgn logik DAN oleh pemanggil ([_MembersPageState._filter]).
class _SearchAndFilterBar extends StatelessWidget {
  const _SearchAndFilterBar({
    required this.controller,
    required this.departments,
    required this.selectedCode,
    required this.onDepartmentSelected,
  });

  final TextEditingController controller;
  final List<_DeptOption> departments;
  final String? selectedCode;
  final ValueChanged<String?> onDepartmentSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Cari nama atau no. ahli',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: controller.clear,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          if (departments.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: selectedCode == null,
                    onSelected: (_) => onDepartmentSelected(null),
                    visualDensity: VisualDensity.compact,
                  ),
                  for (final d in departments) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(d.name),
                      selected: selectedCode == d.code,
                      onSelected: (_) => onDepartmentSelected(d.code),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
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
