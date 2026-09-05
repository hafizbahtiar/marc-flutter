import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/activities/activity_format.dart';
import 'package:marc/features/activities/activity_models.dart';
import 'package:marc/features/activities/activity_providers.dart';
import 'package:marc/features/activities/manage/activity_draft.dart';
import 'package:marc/features/activities/manage/manage_providers.dart';
import 'package:marc/features/activities/manage/management_gate.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/ui/form/custom_datefield.dart';
import 'package:marc/shared/ui/form/custom_textfield.dart';
import 'package:marc/shared/ui/sheet/app_action_sheet.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';
import 'package:marc/shared/ui/dialog/confirm_dialog.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

/// Borang cipta/sunting aktiviti berserta editor sesi.
///
/// [activityId] null = cipta. Aktiviti baharu sentiasa bermula sebagai
/// `draft`; ia tidak kelihatan kepada ahli sehingga diterbitkan.
class ActivityFormPage extends StatelessWidget {
  const ActivityFormPage({super.key, this.activityId});

  final String? activityId;

  @override
  Widget build(BuildContext context) {
    final id = activityId;
    return ManagementGate(
      title: id == null ? 'Aktiviti Baharu' : 'Sunting Aktiviti',
      child: id == null
          ? const _ActivityForm(activity: null)
          : _EditLoader(activityId: id),
    );
  }
}

/// Memuatkan aktiviti SEKALI, kemudian menyerahkannya kepada borang.
///
/// Borang menyalin nilai ke dalam controller dalam `initState` dan bukan
/// semasa `build`: menyemai daripada `AsyncValue` di tengah build bermakna
/// setiap muat semula (selepas terbit/batal) akan memadam apa yang pengurus
/// sedang taip.
class _EditLoader extends ConsumerWidget {
  const _EditLoader({required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(activityDetailProvider(activityId));

    return detail.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Sunting Aktiviti')),
        body: Center(
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
                  onPressed: () =>
                      ref.invalidate(activityDetailProvider(activityId)),
                  child: const Text('Cuba lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (activity) => _ActivityForm(
        // Kunci pada id: menukar aktiviti membina semula State, jadi
        // controller tidak pernah membawa nilai aktiviti sebelumnya.
        key: ValueKey(activity.id),
        activity: activity,
      ),
    );
  }
}

class _ActivityForm extends ConsumerStatefulWidget {
  const _ActivityForm({super.key, required this.activity});

  /// null = mod cipta.
  final Activity? activity;

  @override
  ConsumerState<_ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends ConsumerState<_ActivityForm> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _locationName;
  late final TextEditingController _locationAddress;
  late final TextEditingController _capacity;
  late final TextEditingController _threshold;

  /// Ambang seperti yang DIMUATKAN - nilai yang medan kosong bermakna.
  /// Dalam mod cipta ia 100, iaitu lalai backend.
  late final int _initialThreshold;

  String? _categoryId;
  DateTime? _opensAt;
  DateTime? _closesAt;
  List<SessionDraft> _sessions = [];

  /// Keadaan SEPERTI YANG DIMUATKAN. Inilah asas diff PATCH - tanpa
  /// snapshot ini, "hanya hantar apa yang berubah" tiada makna.
  ActivityDraft? _loadedDraft;
  List<SessionDraft> _loadedSessions = const [];

  bool _busy = false;

  Activity? get _activity => widget.activity;
  bool get _isEdit => _activity != null;

  @override
  void initState() {
    super.initState();
    final a = _activity;

    _title = TextEditingController(text: a?.title ?? '');
    _description = TextEditingController(text: a?.description ?? '');
    _locationName = TextEditingController(text: a?.locationName ?? '');
    _locationAddress = TextEditingController(text: a?.locationAddress ?? '');
    _capacity = TextEditingController(text: a?.capacity?.toString() ?? '');
    _initialThreshold = a?.attendanceThresholdPct ?? 100;
    _threshold = TextEditingController(text: _initialThreshold.toString());

    _categoryId = a == null || a.categoryId.isEmpty ? null : a.categoryId;
    _opensAt = a?.registrationOpensAt;
    _closesAt = a?.registrationClosesAt;

    if (a != null) {
      _sessions = a.sessions.map(SessionDraft.fromSession).toList();
      _sortSessions();
      _loadedDraft = ActivityDraft.fromActivity(a);
      _loadedSessions = _sessions.map((s) => s.copy()).toList();
    } else {
      _sessions = [_defaultSession()];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _locationName.dispose();
    _locationAddress.dispose();
    _capacity.dispose();
    _threshold.dispose();
    super.dispose();
  }

  SessionDraft _defaultSession() {
    final base = _sessions.isEmpty
        ? DateTime.now().add(const Duration(days: 7))
        : _sessions.last.endsAt.add(const Duration(days: 1));
    final start = DateTime(base.year, base.month, base.day, 9);
    return SessionDraft(startsAt: start, endsAt: start.add(_defaultLength));
  }

  static const _defaultLength = Duration(hours: 3);

  /// Kapasiti kosong = TIADA had (lajur nullable), bukan sifar slot.
  /// `_capacityInvalid` membezakan "kosong" daripada "taip benda bukan
  /// nombor" - yang kedua ralat, yang pertama tidak.
  int? get _capacityValue => int.tryParse(_capacity.text.trim());
  bool get _capacityInvalid =>
      _capacity.text.trim().isNotEmpty && _capacityValue == null;

  ActivityDraft _currentDraft() => ActivityDraft(
    categoryId: _categoryId ?? '',
    title: _title.text,
    description: _description.text,
    locationName: _locationName.text,
    locationAddress: _locationAddress.text,
    registrationOpensAt: _opensAt,
    registrationClosesAt: _closesAt,
    capacity: _capacityValue,
    // Medan KOSONG bermakna "biarkan" dan bukan "tetapkan 100". Jatuh ke
    // 100 di sini akan menghantar `attendance_threshold_pct: 100` sebagai
    // perubahan yang pengurus tidak pernah taip - pada aktiviti yang
    // ambangnya 80, mengosongkan medan secara tidak sengaja akan menaikkan
    // syarat sijil untuk semua orang.
    attendanceThresholdPct:
        int.tryParse(_threshold.text.trim()) ?? _initialThreshold,
  );

  String? _validate() {
    if (_capacityInvalid) {
      return 'Kapasiti mesti nombor. Kosongkan untuk tiada had.';
    }
    if (_threshold.text.trim().isNotEmpty &&
        int.tryParse(_threshold.text.trim()) == null) {
      return 'Ambang kehadiran mesti nombor antara 1 dan 100.';
    }
    return validateDraft(_currentDraft(), _sessions);
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      MySnackBar.error(context, problem);
      return;
    }

    setState(() => _busy = true);
    final ok = _isEdit ? await _saveEdit() : await _saveCreate();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && context.canPop()) context.pop();
  }

  Future<bool> _saveCreate() async {
    final result = await ref
        .read(activityManageRepositoryProvider)
        .create(_currentDraft(), _sessions);
    if (!mounted) return false;

    if (!result.isOk) {
      MySnackBar.error(context, result.message!);
      return false;
    }
    MySnackBar.success(
      context,
      'Aktiviti dicipta sebagai draf. Terbitkan bila sedia.',
    );
    return true;
  }

  /// Dua permintaan, dan hanya yang PERLU dihantar.
  ///
  /// PATCH kosong dilangkau sepenuhnya, dan PUT sesi hanya berlaku bila set
  /// sesi benar-benar berubah - kerana PUT itu ditolak 409 sebaik ada
  /// kehadiran direkod, dan menghantarnya "sekadar untuk selamat" akan
  /// menggagalkan suntingan tajuk yang tiada kaitan.
  Future<bool> _saveEdit() async {
    final repo = ref.read(activityManageRepositoryProvider);
    final id = _activity!.id;

    final patch = buildActivityPatch(_loadedDraft!, _currentDraft());
    if (patch.isNotEmpty) {
      final result = await repo.update(id, patch);
      if (!mounted) return false;
      if (!result.isOk) {
        MySnackBar.error(context, result.message!);
        return false;
      }
      // Asas diff bergerak ke hadapan. Kalau PUT sesi di bawah gagal 409,
      // pengurus kekal di skrin ini - dan tekanan Simpan seterusnya tidak
      // patut menghantar semula medan yang SUDAH tersimpan.
      _loadedDraft = _currentDraft();
    }

    if (!sessionsChanged(_loadedSessions, _sessions)) {
      if (!mounted) return false;
      MySnackBar.success(
        context,
        patch.isEmpty
            ? 'Tiada perubahan untuk disimpan.'
            : 'Aktiviti dikemas kini.',
      );
      return true;
    }

    final sessionResult = await repo.replaceSessions(id, _sessions);
    if (!mounted) return false;
    if (!sessionResult.isOk) {
      // Medan aktiviti mungkin SUDAH tersimpan - pengurus perlu tahu itu,
      // jika tidak dia akan menyunting semula perkara yang sudah berjaya.
      MySnackBar.error(
        context,
        patch.isEmpty
            ? sessionResult.message!
            : 'Maklumat aktiviti disimpan, tetapi sesi tidak: '
                  '${sessionResult.message}',
      );
      return false;
    }

    _loadedSessions = _sessions.map((s) => s.copy()).toList();
    MySnackBar.success(context, 'Aktiviti dan sesi dikemas kini.');
    return true;
  }

  Future<void> _publish() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Terbitkan aktiviti',
      message:
          'Setiap ahli yang diluluskan akan menerima notifikasi dan '
          'pendaftaran dibuka. Teruskan?',
      confirmLabel: 'Terbitkan',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(activityManageRepositoryProvider)
        .publish(_activity!.id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isOk) {
      MySnackBar.success(context, 'Aktiviti diterbitkan.');
    } else {
      MySnackBar.error(context, result.message!);
    }
  }

  Future<void> _cancelActivity() async {
    final reason = await showReasonDialog(
      context,
      title: 'Batalkan aktiviti',
      message:
          'Sebab ini dihantar kepada setiap ahli yang berdaftar. '
          'Pembatalan tidak boleh diundur.',
      confirmLabel: 'Batalkan',
      hint: 'Contoh: dewan tidak tersedia',
      isDestructive: true,
    );
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(activityManageRepositoryProvider)
        .cancel(_activity!.id, reason);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isOk) {
      MySnackBar.success(context, 'Aktiviti dibatalkan.');
    } else {
      MySnackBar.error(context, result.message!);
    }
  }

  /// Senarai dipapar mengikut KRONOLOGI, susunan yang sama yang menentukan
  /// `seq` semasa dihantar. Kad "Sesi 2" pada skrin dengan itu ialah sesi
  /// yang akan dilabel "Sesi 2" pada pemilih kehadiran.
  void _sortSessions() {
    _sessions.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  void _applySessionStart(SessionDraft s, DateTime picked) {
    setState(() {
      final length = s.endsAt.difference(s.startsAt);
      s.startsAt = picked;
      // Masa tamat digerakkan bersama supaya julat tidak menjadi negatif
      // secara senyap semasa pengurus menukar tarikh sahaja.
      s.endsAt = picked.add(length.isNegative ? _defaultLength : length);
      _sortSessions();
    });
  }

  void _applySessionEnd(SessionDraft s, DateTime picked) {
    setState(() => s.endsAt = picked);
  }

  /// Bottom sheet (bukan dropdown) - padanan pemilih role di
  /// `members_page.dart`, guna semula `showAppActionSheet`.
  Future<void> _pickCategory(List<ActivityCategory> rows) async {
    if (rows.isEmpty) return;
    final selected = await showAppActionSheet<ActivityCategory>(
      context,
      title: 'Pilih kategori',
      actions: [
        for (final c in rows)
          AppSheetAction(
            value: c,
            label: c.name,
            isSelected: c.id == _categoryId,
          ),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() => _categoryId = selected.id);
  }

  String _selectedCategoryName(List<ActivityCategory> rows) {
    for (final c in rows) {
      if (c.id == _categoryId) return c.name;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(activityCategoriesProvider);
    final rows = categories.valueOrNull ?? const <ActivityCategory>[];
    final a = _activity;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sunting Aktiviti' : 'Aktiviti Baharu'),
        actions: [
          if (a != null)
            PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: (value) {
                switch (value) {
                  case 'publish':
                    _publish();
                  case 'cancel':
                    _cancelActivity();
                  case 'registrations':
                    context.push('/activities/${a.id}/registrations');
                  case 'certificates':
                    context.push('/activities/${a.id}/certificates');
                }
              },
              itemBuilder: (_) => [
                if (a.status == 'draft')
                  const PopupMenuItem(
                    value: 'publish',
                    child: Text('Terbitkan'),
                  ),
                const PopupMenuItem(
                  value: 'registrations',
                  child: Text('Senarai peserta'),
                ),
                const PopupMenuItem(
                  value: 'certificates',
                  child: Text('Terbitkan sijil'),
                ),
                if (a.status != 'cancelled')
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Batalkan aktiviti'),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (a != null) _StatusBanner(activity: a),

            Row(
              children: [
                const Expanded(
                  child: FormFieldLabel('Kategori', padding: EdgeInsets.zero),
                ),
                // Pintasan - pintu utama di Tetapan (admin/superadmin).
                if (ref.watch(isAdminOrAboveProvider))
                  TextButton(
                    onPressed: () => context.push('/activities/categories'),
                    child: const Text('Urus kategori'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _pickCategory(rows),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                // isEmpty MESTI ditetapkan - lalai InputDecorator ialah
                // false, jadi hintText tak pernah dipapar langsung tanpanya
                // (medan nampak kosong-kosong sahaja walaupun belum pilih).
                isEmpty: _categoryId == null,
                decoration: const InputDecoration(
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  hintText: 'Pilih kategori',
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(_selectedCategoryName(rows))),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            if (categories.hasError)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Gagal memuat senarai kategori.'),
              ),

            const SizedBox(height: 18),
            CustomTextField(
              controller: _title,
              label: 'Tajuk',
              hint: 'Nama aktiviti',
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 18),
            CustomTextField(
              controller: _description,
              label: 'Penerangan',
              hint: 'Ringkasan aktiviti',
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 18),
            CustomTextField(
              controller: _locationName,
              label: 'Lokasi',
              hint: 'Nama tempat',
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _locationAddress,
              label: 'Alamat',
              hint: 'Alamat penuh (pilihan)',
              maxLines: 2,
            ),

            const SizedBox(height: 18),
            CustomDateField(
              label: 'Buka pendaftaran (pilihan)',
              value: _opensAt,
              hint: 'Sebaik diterbitkan',
              includeTime: true,
              format: formatDateTime,
              canClear: true,
              firstDate: DateTime(DateTime.now().year - 2),
              lastDate: DateTime(DateTime.now().year + 5),
              onChanged: (v) => setState(() => _opensAt = v),
            ),
            const SizedBox(height: 12),
            CustomDateField(
              label: 'Tutup pendaftaran',
              value: _closesAt,
              hint: 'Belum ditetapkan',
              includeTime: true,
              format: formatDateTime,
              firstDate: DateTime(DateTime.now().year - 2),
              lastDate: DateTime(DateTime.now().year + 5),
              onChanged: (v) {
                if (v != null) setState(() => _closesAt = v);
              },
            ),

            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _capacity,
                    label: 'Kapasiti',
                    hint: 'Tiada had',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _threshold,
                    label: 'Ambang kehadiran (%)',
                    hint: '100',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Kapasiti kosong bermakna tiada had. Ambang kehadiran '
                'menentukan peratus sesi yang perlu dihadiri untuk layak '
                'menerima sijil.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FormFieldLabel(
                    'Sesi (${_sessions.length})',
                    padding: EdgeInsets.zero,
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _sessions.add(_defaultSession());
                          _sortSessions();
                        }),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah sesi'),
                ),
              ],
            ),
            Text(
              'Tarikh aktiviti dikira daripada sesi - sesi pertama hingga '
              'sesi terakhir.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _sessions.length; i++)
              _SessionCard(
                key: ObjectKey(_sessions[i]),
                index: i,
                session: _sessions[i],
                onTitleChanged: (v) => _sessions[i].title = v,
                onStartChanged: (v) {
                  if (v != null) _applySessionStart(_sessions[i], v);
                },
                onEndChanged: (v) {
                  if (v != null) _applySessionEnd(_sessions[i], v);
                },
                onRemove: _sessions.length == 1
                    ? null
                    : () => setState(() => _sessions.removeAt(i)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _busy
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator.adaptive(),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_isEdit ? 'Simpan' : 'Cipta draf'),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Dialog yang memaksa sebab bukan kosong sebelum butang sah aktif.
///
/// Dipakai oleh pembatalan aktiviti DAN pindaan kehadiran - kedua-duanya
/// tindakan yang backend tolak 400 tanpa sebab, dan kedua-duanya masuk ke
/// jejak audit sebagai sebab yang ditaip manusia.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String hint = 'Sebab',
  bool isDestructive = false,
}) {
  // Butang mati sehingga ada sebab: backend menolak sebab kosong 400, dan
  // mesej ralat selepas fakta lebih teruk daripada butang yang jelas belum
  // boleh ditekan (lihat validator lalai showAppInputDialog).
  return showAppInputDialog(
    context,
    title: title,
    message: message,
    positiveLabel: confirmLabel,
    hint: hint,
    maxLines: 3,
    isDestructive: isDestructive,
  );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    // 'draft' kekal `tertiary` (biru diraja) - ia status *maklumat*, bukan
    // berjaya. Hijau `success` disimpan untuk 'published', satu-satunya
    // keadaan positif di sini.
    final (String text, Color color) = switch (activity.status) {
      'draft' => (
        'Draf - belum kelihatan kepada ahli. Terbitkan dari menu di atas.',
        theme.colorScheme.tertiary,
      ),
      'cancelled' => (
        'Dibatalkan: ${activity.cancelledReason ?? "-"}',
        theme.colorScheme.error,
      ),
      'completed' => ('Aktiviti tamat.', theme.colorScheme.onSurfaceVariant),
      _ => ('Diterbitkan.', semantic.success),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    super.key,
    required this.index,
    required this.session,
    required this.onTitleChanged,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onRemove,
  });

  final int index;
  final SessionDraft session;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2);
    final lastDate = DateTime(now.year + 5);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sesi ${index + 1}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Buang sesi',
                    onPressed: onRemove,
                  ),
              ],
            ),
            CustomTextField(
              initialValue: session.title,
              label: 'Tajuk sesi',
              hint: 'Pilihan',
              onChanged: onTitleChanged,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            CustomDateField(
              label: 'Mula',
              value: session.startsAt,
              hint: '-',
              includeTime: true,
              format: formatDateTime,
              firstDate: firstDate,
              lastDate: lastDate,
              onChanged: onStartChanged,
            ),
            const SizedBox(height: 12),
            CustomDateField(
              label: 'Tamat',
              value: session.endsAt,
              hint: '-',
              includeTime: true,
              format: formatDateTime,
              firstDate: firstDate,
              lastDate: lastDate,
              onChanged: onEndChanged,
            ),
            if (!session.isValid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Masa tamat mesti selepas masa mula.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
