/// Blok statistik pengurusan pada skrin Utama. Hanya dibina apabila
/// backend menghantar `admin != null` - kelayakan ditentukan di sana,
/// bukan ditebak oleh client.
///
/// Susun atur bento: dua petak angka bersebelahan, satu petak kutipan
/// penuh lebar dengan angka besar, kemudian dua kad pecahan. Saiz yang
/// berbeza itulah hierarkinya - bukan warna yang berbeza-beza, kerana
/// seluruh skrin diolah daripada `primary`/`secondary` sahaja.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/features/dashboard/dashboard_models.dart';
import 'package:marc/features/dashboard/widgets/bento.dart';

String _formatCents(int cents) => 'RM ${(cents / 100).toStringAsFixed(2)}';

class AdminSection extends StatelessWidget {
  const AdminSection({super.key, required this.admin});

  final AdminBlock admin;

  @override
  Widget build(BuildContext context) {
    final perluTindakan = admin.pendingApprovals > 0;
    final revenue = admin.revenue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BentoRow(
          children: [
            // Navy pekat HANYA bila ada yang menunggu. Petak kosong yang
            // berwarna melatih orang mengabaikan warna itu.
            BentoStat(
              label: 'Menunggu kelulusan',
              value: '${admin.pendingApprovals}',
              tone: perluTindakan ? BentoTone.secondary : BentoTone.surface,
              onTap: () => context.push('/members/pending'),
            ),
            BentoStat(
              label: 'Aktiviti akan datang',
              value: '${admin.activityStats.upcoming}',
              onTap: () => context.push('/activities'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BentoStat(
            label: 'Kutipan bulan ini',
            value: _formatCents(revenue.totalCents),
            big: true,
            tone: BentoTone.primarySoft,
            // Nota WAJIB apabila `donationCents` null: nilai null
            // bermakna pemanggil bukan superadmin, jadi jumlah ini
            // memang tidak lengkap dan kad tidak boleh berdiam diri
            // tentang itu.
            footnote: revenue.includesDonations
                ? null
                : 'Jumlah ini tidak termasuk derma',
            onTap: () => context.push('/admin/payments'),
          ),
        ),
        const SizedBox(height: 12),
        _MemberStatsCard(stats: admin.memberStats),
        const SizedBox(height: 12),
        _ActivityStatsCard(stats: admin.activityStats),
      ],
    );
  }
}

class _MemberStatsCard extends StatelessWidget {
  const _MemberStatsCard({required this.stats});

  final MemberStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BentoTile(
        onTap: () => context.push('/members'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistik Ahli', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _LabelledValue(label: 'Aktif', value: '${stats.active}'),
                _LabelledValue(label: 'Pending', value: '${stats.pending}'),
                _LabelledValue(
                  label: 'Baharu bulan ini',
                  value: '${stats.newThisMonth}',
                ),
              ],
            ),
            if (stats.byDepartment.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...stats.byDepartment.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${d.count}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityStatsCard extends StatelessWidget {
  const _ActivityStatsCard({required this.stats});

  final ActivityStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `attendanceRate` null bermakna tiada sesi tamat bulan ini - BUKAN
    // sama dengan kehadiran sifar, jadi papar "-".
    final kadar = stats.attendanceRate == null
        ? '-'
        : '${(stats.attendanceRate! * 100).round()}%';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BentoTile(
        onTap: () => context.push('/activities'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistik Aktiviti', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _LabelledValue(
                  label: 'Pendaftaran bulan ini',
                  value: '${stats.registrationsThisMonth}',
                ),
                _LabelledValue(label: 'Kehadiran', value: kadar),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelledValue extends StatelessWidget {
  const _LabelledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
