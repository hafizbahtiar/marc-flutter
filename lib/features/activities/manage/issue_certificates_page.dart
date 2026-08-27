import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/activities/activity_format.dart';
import 'package:marc/features/activities/activity_models.dart';
import 'package:marc/features/activities/activity_providers.dart';
import 'package:marc/features/activities/manage/manage_providers.dart';
import 'package:marc/features/activities/manage/management_gate.dart';
import 'package:marc/shared/ui/dialog/confirm_dialog.dart';

/// Terbitkan sijil untuk satu aktiviti.
///
/// Endpoint ini boleh diulang dengan selamat: ia melangkau sesiapa yang
/// sudah bersijil dan menyambung muat naik fail yang belum siap. Itu yang
/// menjadikan 202 sebagai "sambung nanti" dan bukan "cuba lagi kerana ia
/// gagal".
class IssueCertificatesPage extends StatelessWidget {
  const IssueCertificatesPage({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context) {
    return ManagementGate(
      title: 'Terbitkan Sijil',
      child: _IssueBody(activityId: activityId),
    );
  }
}

class _IssueBody extends ConsumerStatefulWidget {
  const _IssueBody({required this.activityId});

  final String activityId;

  @override
  ConsumerState<_IssueBody> createState() => _IssueBodyState();
}

class _IssueBodyState extends ConsumerState<_IssueBody> {
  bool _busy = false;
  IssueCertificatesResult? _result;

  Future<void> _issue(Activity activity) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Terbitkan sijil',
      message:
          'Sijil akan diterbitkan untuk setiap peserta yang mencapai '
          '${activity.attendanceThresholdPct}% kehadiran. Sijil yang sudah '
          'ada tidak akan diterbitkan dua kali.',
      confirmLabel: 'Terbitkan',
    );
    if (!ok || !mounted) return;

    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await ref
        .read(activityManageRepositoryProvider)
        .issueCertificates(widget.activityId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(activityDetailProvider(widget.activityId));

    return Scaffold(
      appBar: AppBar(title: const Text('Terbitkan Sijil')),
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
          data: (activity) => _content(context, activity),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Activity activity) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    // Backend menolak 422 sebelum sesi terakhir tamat (`activities.ends_at`
    // ialah max sesi). Disemak di sini juga supaya butang tidak menjemput
    // ketukan yang pasti ditolak.
    final finished = DateTime.now().isAfter(activity.endsAt);
    final sessionCount = activity.sessions.length;
    final needed = sessionCount == 0
        ? 0
        : (sessionCount * activity.attendanceThresholdPct / 100).ceil();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(activity.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          formatRange(activity.startsAt, activity.endsAt),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Syarat kelayakan', style: theme.textTheme.titleSmall),
                const SizedBox(height: 10),
                _Stat(
                  label: 'Peserta berdaftar',
                  value: '${activity.registrationCount}',
                ),
                _Stat(label: 'Jumlah sesi', value: '$sessionCount'),
                _Stat(
                  label: 'Ambang kehadiran',
                  value: '${activity.attendanceThresholdPct}%',
                ),
                _Stat(
                  label: 'Sesi minimum untuk layak',
                  value: sessionCount == 0
                      ? '-'
                      : '$needed daripada $sessionCount',
                ),
                const SizedBox(height: 10),
                Text(
                  // Kiraan LAYAK sebenar tidak boleh dikira di sini: tiada '
                  // endpoint yang mendedahkan kehadiran per peserta, jadi
                  // angka yang direka di skrin ini akan menjadi tekaan yang
                  // kelihatan berwibawa.
                  'Bilangan sebenar yang layak dikira oleh pelayan semasa '
                  'penerbitan, berdasarkan kehadiran yang direkodkan.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (activity.certificatesIssuedAt != null) ...[
          const SizedBox(height: 14),
          _Note(
            icon: Icons.workspace_premium_outlined,
            color: theme.colorScheme.primary,
            text:
                'Sijil pernah diterbitkan pada '
                '${formatDateTime(activity.certificatesIssuedAt!)}. '
                'Menerbitkan semula hanya menambah peserta baharu yang layak '
                'dan menyambung fail yang belum siap.',
          ),
        ],

        if (!finished) ...[
          const SizedBox(height: 14),
          _Note(
            icon: Icons.schedule,
            color: semantic.warning,
            text:
                'Sijil hanya boleh diterbitkan selepas sesi terakhir tamat '
                '(${formatDateTime(activity.endsAt)}).',
          ),
        ],

        if (activity.isCancelled) ...[
          const SizedBox(height: 14),
          _Note(
            icon: Icons.cancel_outlined,
            color: theme.colorScheme.error,
            text: 'Aktiviti ini telah dibatalkan.',
          ),
        ],

        const SizedBox(height: 22),
        if (_busy)
          const Center(child: CircularProgressIndicator.adaptive())
        else
          FilledButton.icon(
            onPressed: finished ? () => _issue(activity) : null,
            icon: const Icon(Icons.workspace_premium),
            label: Text(
              activity.certificatesIssuedAt == null
                  ? 'Terbitkan sijil'
                  : 'Terbitkan / sambung',
            ),
          ),

        if (_result != null) ...[
          const SizedBox(height: 20),
          _ResultCard(result: _result!),
        ],
      ],
    );
  }
}

/// Keputusan penerbitan dipapar KEKAL pada skrin, bukan sebagai snackbar.
///
/// 202 membawa dua kiraan dan satu arahan susulan ("panggil semula"). Itu
/// bukan maklumat yang patut hilang selepas tiga saat.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final IssueCertificatesResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    if (!result.ok) {
      return _Note(
        icon: Icons.error_outline,
        color: theme.colorScheme.error,
        text: result.message!,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Note(
          icon: result.partial ? Icons.hourglass_bottom : Icons.check_circle,
          color: result.partial ? semantic.warning : theme.colorScheme.primary,
          text: result.partial ? result.message! : 'Sijil siap diterbitkan.',
        ),
        // Kiraan hanya dipapar bila ia benar-benar dibaca daripada respons.
        // Panggilan yang tamat masa tidak membawa kiraan; "0 diterbitkan"
        // di situ akan bercanggah dengan mesej di atasnya.
        if (result.countsKnown) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Stat(
                    label: 'Sijil baharu diterbitkan',
                    value: '${result.issued}',
                  ),
                  _Stat(
                    label: 'Fail sedia dimuat turun',
                    value: '${result.filesReady}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
