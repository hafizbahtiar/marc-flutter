import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/activities/activity_format.dart';
import 'package:marc/features/activities/activity_models.dart';
import 'package:marc/features/activities/activity_providers.dart';
import 'package:marc/features/activities/manage/manage_providers.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  const ActivityDetailPage({super.key, required this.activityId});

  final String activityId;

  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  bool _busy = false;

  Future<void> _register() async {
    setState(() => _busy = true);
    final result = await ref
        .read(activityRepositoryProvider)
        .register(widget.activityId);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isOk) {
      MySnackBar.success(context, 'Pendaftaran berjaya.');
    } else {
      // Termasuk 409 — "aktiviti sudah penuh" / "anda sudah berdaftar" /
      // "pendaftaran telah ditutup". Mesej datang terus dari backend dalam
      // Bahasa Melayu; kiraan sudah digulung semula dan detail
      // di-invalidate oleh repository, jadi paparan akan menunjukkan
      // keadaan sebenar sebaik ia dimuat semula.
      MySnackBar.error(context, result.message!);
    }
  }

  Future<void> _cancel() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Batal pendaftaran',
      message: 'Anda pasti mahu batalkan pendaftaran untuk aktiviti ini?',
      confirmLabel: 'Batalkan',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(activityRepositoryProvider)
        .cancel(widget.activityId);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isOk) {
      MySnackBar.success(context, 'Pendaftaran dibatalkan.');
    } else {
      MySnackBar.error(context, result.message!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(activityDetailProvider(widget.activityId));
    // valueOrNull SEKALI, dan bar tindakan dibina daripada nilai itu —
    // `AsyncValue.value` MEMBALING pada keadaan ralat walaupun data lama
    // masih ada (selepas invalidate yang gagal refetch), yang akan
    // menjatuhkan halaman ini tepat pada saat pendaftaran ditolak.
    final activity = detail.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktiviti'),
        actions: [
          // Pintu ke skrin pengurusan. Disembunyikan daripada ahli biasa
          // sebagai kemudahan sahaja — backend menolak setiap route di
          // sebaliknya dengan 403.
          if (ref.watch(isManagementProvider))
            PopupMenuButton<String>(
              onSelected: (value) =>
                  context.push('/activities/${widget.activityId}/$value'),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sunting')),
                PopupMenuItem(
                  value: 'registrations',
                  child: Text('Senarai peserta'),
                ),
                PopupMenuItem(
                  value: 'certificates',
                  child: Text('Terbitkan sijil'),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: detail.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Gagal memuat aktiviti.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(
                      activityDetailProvider(widget.activityId),
                    ),
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (activity) => _DetailBody(activity: activity),
        ),
      ),
      bottomNavigationBar: activity == null
          ? null
          : _ActionBar(
              activity: activity,
              busy: _busy,
              onRegister: _register,
              onCancel: _cancel,
            ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(activity.title, style: theme.textTheme.headlineSmall),
        if (activity.categoryName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            activity.categoryName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        if (activity.isCancelled) ...[
          const SizedBox(height: 14),
          _Banner(
            icon: Icons.cancel_outlined,
            color: theme.colorScheme.error,
            text: activity.cancelledReason?.isNotEmpty == true
                ? 'Aktiviti dibatalkan: ${activity.cancelledReason}'
                : 'Aktiviti ini telah dibatalkan.',
          ),
        ] else if (activity.isRegistered) ...[
          const SizedBox(height: 14),
          _Banner(
            icon: Icons.check_circle_outline,
            color: theme.colorScheme.primary,
            text: 'Anda telah berdaftar untuk aktiviti ini.',
          ),
        ],

        const SizedBox(height: 18),
        _InfoRow(
          icon: Icons.event_outlined,
          label: 'Tarikh',
          value: formatRange(activity.startsAt, activity.endsAt),
        ),
        _InfoRow(
          icon: Icons.place_outlined,
          label: 'Lokasi',
          value: [
            activity.locationName,
            activity.locationAddress,
          ].where((s) => s.isNotEmpty).join('\n'),
        ),
        _InfoRow(
          icon: Icons.how_to_reg_outlined,
          label: 'Pendaftaran ditutup',
          value: formatDateTime(activity.registrationClosesAt),
        ),
        _InfoRow(
          icon: Icons.people_outline,
          label: 'Penyertaan',
          // capacity null = tiada had. Jangan papar "/0".
          value: activity.capacity == null
              ? '${activity.registrationCount} pendaftaran (tiada had)'
              : '${activity.registrationCount} / ${activity.capacity} terisi',
        ),

        if (activity.description.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Keterangan', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(activity.description, style: theme.textTheme.bodyLarge),
        ],

        // Sesi hanya bermakna bila ada LEBIH daripada satu: aktiviti satu
        // sesi sudah pun diringkaskan sepenuhnya oleh baris "Tarikh" di
        // atas, jadi mengulanginya cuma bunyi bising.
        if (activity.sessions.length > 1) ...[
          const SizedBox(height: 20),
          Text('Sesi', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final s in activity.sessions)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    child: Text(
                      '${s.seq}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title.isNotEmpty ? s.title : 'Sesi ${s.seq}',
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          formatRange(s.startsAt, s.endsAt),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Butang daftar/batal. Butang yang DILUMPUHKAN membawa sebabnya —
/// butang kelabu tanpa penjelasan meninggalkan ahli meneka sama ada app
/// yang rosak atau memang mereka tak layak.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.activity,
    required this.busy,
    required this.onRegister,
    required this.onCancel,
  });

  final Activity activity;
  final bool busy;
  final VoidCallback onRegister;
  final VoidCallback onCancel;

  /// Memetakan gerbang TUNGGAL model kepada ayat — ia TIDAK membuat
  /// keputusan sendiri. Butang dilumpuhkan oleh `activity.canRegister`,
  /// jadi teks di sini tak boleh bercanggah dengan keadaan butang.
  String? get _blockedReason {
    return switch (activity.registrationBlocker) {
      null => null,
      RegistrationBlocker.cancelled => 'Aktiviti ini telah dibatalkan.',
      RegistrationBlocker.completed => 'Aktiviti ini telah tamat.',
      RegistrationBlocker.notPublished => 'Pendaftaran belum dibuka.',
      RegistrationBlocker.opensLater =>
        'Pendaftaran dibuka pada ${formatDateTime(activity.registrationOpensAt!)}.',
      RegistrationBlocker.closed => 'Pendaftaran telah ditutup.',
      RegistrationBlocker.full => 'Aktiviti ini sudah penuh.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget child;
    if (activity.isRegistered) {
      child = OutlinedButton.icon(
        onPressed: busy ? null : onCancel,
        icon: const Icon(Icons.close),
        label: const Text('Batal pendaftaran'),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
        ),
      );
    } else {
      final reason = _blockedReason;
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reason != null) ...[
            Text(
              reason,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.extension<AppSemanticColors>()!.warning,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            // Gerbang sebenar ialah `canRegister` — bukan kehadiran teks
            // di atas. Kedua-duanya kini berpunca dari getter yang sama.
            onPressed: (busy || !activity.canRegister) ? null : onRegister,
            icon: const Icon(Icons.how_to_reg),
            label: const Text('Daftar'),
          ),
        ],
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: busy
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator.adaptive(),
                ),
              )
            : SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
