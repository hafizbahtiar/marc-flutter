import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/features/activities/activity_format.dart';
import 'package:marc/features/activities/activity_models.dart';
import 'package:marc/features/activities/activity_providers.dart';
import 'package:marc/features/activities/manage/activity_form_page.dart'
    show showReasonDialog;
import 'package:marc/features/activities/manage/manage_providers.dart';
import 'package:marc/features/activities/manage/management_gate.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

/// Senarai peserta satu aktiviti, dengan tanda hadir per SESI.
///
/// Kehadiran ialah per-sesi, bukan per-aktiviti — jadi pemilih sesi di atas
/// bukan hiasan: menandakan seseorang "hadir" tanpa memilih sesi tiada
/// makna dalam skema ini, dan sijil dikira daripada bilangan sesi yang
/// dihadiri berbanding ambang aktiviti.
class RegistrationsPage extends StatelessWidget {
  const RegistrationsPage({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context) {
    return ManagementGate(
      title: 'Senarai Peserta',
      child: _RegistrationsBody(activityId: activityId),
    );
  }
}

class _RegistrationsBody extends ConsumerStatefulWidget {
  const _RegistrationsBody({required this.activityId});

  final String activityId;

  @override
  ConsumerState<_RegistrationsBody> createState() => _RegistrationsBodyState();
}

class _RegistrationsBodyState extends ConsumerState<_RegistrationsBody> {
  String? _sessionId;

  /// TINDIHAN tempatan ke atas `attended_session_ids` yang datang dari
  /// server, mengikut id pendaftaran.
  ///
  /// Keadaan asas dibaca daripada senarai peserta (satu permintaan menyemai
  /// keseluruhan skrin); peta ini hanya membawa perubahan yang skrin INI
  /// buat selepas itu, supaya suis tidak perlu menunggu muat semula penuh.
  /// Ia dikosongkan setiap kali sesi bertukar atau senarai dibaca semula —
  /// selepas itu server yang menjadi kebenaran semula.
  final Map<String, bool> _marked = {};

  /// Baris yang permintaannya dalam penerbangan, dikunci pada
  /// SESI + pendaftaran.
  ///
  /// Kunci gabungan dan bukan id pendaftaran sahaja: permintaan sesi 1 yang
  /// selesai lewat tidak boleh memadam spinner permintaan sesi 2 bagi orang
  /// yang sama. Dengan id sahaja, kedua-duanya berkongsi satu entri dan
  /// pembersihan yang tepat mustahil.
  final Set<String> _busy = {};

  static String _busyKey(String sessionId, String personId) =>
      '$sessionId|$personId';

  /// Sesi yang sedang dipapar. Diselesaikan daripada satu tempat supaya
  /// laluan async dan `build` mustahil tidak bersetuju tentang sesi mana
  /// yang dimaksudkan.
  String? _resolvedSessionId() {
    final chosen = _sessionId;
    if (chosen != null) return chosen;
    final sessions = ref
        .read(activityDetailProvider(widget.activityId))
        .valueOrNull
        ?.sessions;
    return sessions == null || sessions.isEmpty ? null : sessions.first.id;
  }

  void _selectSession(String? id) {
    setState(() {
      _sessionId = id;
      // Kehadiran milik SESI. Membawa tanda ATAU spinner sesi 1 ke paparan
      // sesi 2 akan menunjukkan pembohongan yang meyakinkan.
      _marked.clear();
      _busy.clear();
    });
  }

  void _resetOverrides() {
    _marked.clear();
    _busy.clear();
  }

  /// Buka pengimbas untuk sesi yang SEDANG dipapar.
  ///
  /// Tindihan tempatan dikosongkan selepas kembali: pengimbas menanda
  /// kehadiran melalui repository yang sama (dan membatalkan cache senarai),
  /// jadi data server kini lebih baharu daripada apa-apa yang skrin ini
  /// masih pegang. Tanpa ini, seseorang yang dibuang tandanya di sini lalu
  /// diimbas hadir di sana akan kekal dipapar TIDAK hadir.
  Future<void> _openScanner(String sessionId) async {
    await context.push(
      '/activities/${widget.activityId}/sessions/$sessionId/scan',
    );
    if (mounted) setState(_resetOverrides);
  }

  /// QR venue utk daftar hadir SENDIRI ahli (`self_scan`) — beza drpd
  /// `_openScanner` (pengurusan imbas QR PERIBADI ahli lain). Tiada
  /// perlu `setState(_resetOverrides)` selepas kembali: skrin ni cuma
  /// PAPAR QR, tak sentuh kehadiran secara langsung sendiri (ahli yang
  /// imbas nanti, di skrin lain).
  void _openSessionQr(String sessionId) {
    context.push(
      '/activities/${widget.activityId}/sessions/$sessionId/checkin-qr',
    );
  }

  Future<void> _setAttendance(
    ActivityRegistrant person,
    bool present,
    String sessionId,
  ) async {
    final key = _busyKey(sessionId, person.id);
    setState(() => _busy.add(key));

    final outcome = present
        ? await _mark(person, sessionId)
        : await _unmark(person, sessionId);
    if (!mounted) return;

    // Sesi mungkin sudah bertukar semasa permintaan dalam penerbangan.
    // Menulis hasilnya sekarang akan menandakan orang ini hadir untuk sesi
    // yang dia TIDAK dihadiri — dan kerana suis kini menunjukkan data
    // sebenar, pembohongan itu kelihatan berwibawa.
    if (_resolvedSessionId() != sessionId) {
      // Entri busy TETAP dibuang. `_selectSession` sudah mengosongkan set
      // itu hari ini, jadi ini tidak boleh dicapai — tetapi kunci
      // bersesi bermakna pembersihan ini tepat dan bukan spekulasi, dan
      // laluan yang meninggalkan spinner kekal hidup pada satu baris ialah
      // jenis kerosakan yang hanya muncul selepas refactor kemudian.
      setState(() => _busy.remove(key));
      return;
    }

    setState(() {
      _busy.remove(key);
      final state = outcome.state;
      if (state != null) _marked[person.id] = state;
    });

    // Toast SELEPAS penjaga. Sebelum ini "Ali ditanda hadir." dipapar dari
    // dalam `_mark`, jadi hasil yang dibuang tetap menghijaukan skrin di
    // atas senarai sesi BAHARU — pengesahan bagi tanda yang tidak berlaku
    // di sana. Ralat sengaja TIDAK dilewatkan begitu (lihat `_mark`):
    // kegagalan ialah maklumat yang tidak boleh ditelan diam-diam, dan
    // merah tidak boleh disalah baca sebagai pengesahan.
    final success = outcome.success;
    if (success != null) MySnackBar.success(context, success);
  }

  /// [state] = keadaan suis BARU, atau null bila tiada apa yang berubah
  /// (gagal atau dibatalkan pengguna). [success] = teks kejayaan yang
  /// pemanggil papar SELEPAS penjaga sesi; null bila tiada.
  Future<({bool? state, String? success})> _mark(
    ActivityRegistrant person,
    String sessionId,
  ) async {
    final repo = ref.read(activityManageRepositoryProvider);
    var result = await repo.markAttendance(
      activityId: widget.activityId,
      sessionId: sessionId,
      registrationId: person.id,
    );

    const nothing = (state: null, success: null);

    if (result.outsideWindow) {
      if (!mounted) return nothing;
      final reason = await showReasonDialog(
        context,
        title: 'Pindaan kehadiran',
        message:
            '${result.message} Tandakan sebagai pindaan? Sebab akan '
            'direkodkan dalam jejak audit sebagai pembetulan.',
        confirmLabel: 'Tanda sebagai pindaan',
        hint: 'Contoh: lupa scan semasa sesi',
      );
      if (reason == null || !mounted) return nothing;

      result = await repo.markAttendance(
        activityId: widget.activityId,
        sessionId: sessionId,
        registrationId: person.id,
        amendReason: reason,
      );
    }

    if (!mounted) return nothing;
    if (!result.ok) {
      // Ralat dipapar SERTA-MERTA, tidak seperti kejayaan: kegagalan yang
      // ditelan diam-diam kerana pengurus menukar sesi ialah kegagalan yang
      // dia tidak akan tahu berlaku.
      MySnackBar.error(context, result.message!);
      return nothing;
    }
    return (
      state: true,
      success: result.created
          ? '${person.name} ditanda hadir.'
          : '${person.name} memang sudah ditanda hadir.',
    );
  }

  Future<({bool? state, String? success})> _unmark(
    ActivityRegistrant person,
    String sessionId,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Buang kehadiran',
      message:
          'Buang kehadiran ${person.name} untuk sesi ini? Kehadiran ialah '
          'bukti yang menentukan kelayakan sijil.',
      confirmLabel: 'Buang',
      isDestructive: true,
    );
    const nothing = (state: null, success: null);
    if (!confirmed || !mounted) return nothing;

    final result = await ref
        .read(activityManageRepositoryProvider)
        .unmarkAttendance(
          activityId: widget.activityId,
          sessionId: sessionId,
          registrationId: person.id,
        );
    if (!mounted) return nothing;
    if (!result.isOk) {
      MySnackBar.error(context, result.message!);
      return nothing;
    }
    return (state: false, success: 'Kehadiran ${person.name} dibuang.');
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(activityDetailProvider(widget.activityId));
    final registrants = ref.watch(
      activityRegistrantsProvider(widget.activityId),
    );
    final sessions = detail.valueOrNull?.sessions ?? const <ActivitySession>[];

    // Sesi pertama dipilih secara automatik supaya skrin berguna sebaik
    // dibuka; pilihan pengurus tidak pernah ditindih selepas itu.
    final selected = _resolvedSessionId();

    return Scaffold(
      // Pintu ke pengimbas QR. Diletakkan DI SINI dan bukan pada menu
      // halaman aktiviti kerana sesi dipilih di skrin ini: pengimbas
      // mewarisi sesi yang sedang dipapar, jadi mustahil untuk mengimbas
      // barisan penuh ke dalam sesi yang tidak dilihat sesiapa.
      //
      // Dimatikan bila tiada sesi dipilih — kehadiran adalah per-sesi, dan
      // butang yang membuka kamera tanpa sasaran hanya boleh mengecewakan
      // selepas imbasan pertama.
      floatingActionButton: FloatingActionButton.extended(
        // heroTag unik — lihat komen padanan di feed_page.dart (elak
        // clash Hero dgn FAB tab shell yang tetap mounted di belakang
        // route push ni).
        heroTag: 'registrations-fab',
        onPressed: selected == null ? null : () => _openScanner(selected),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Imbas QR'),
      ),
      appBar: AppBar(
        title: const Text('Senarai Peserta'),
        actions: [
          IconButton(
            tooltip: 'Papar QR daftar hadir (ahli imbas sendiri)',
            icon: const Icon(Icons.qr_code_2_outlined),
            onPressed: selected == null ? null : () => _openSessionQr(selected),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: _SessionPicker(
            sessions: sessions,
            selectedId: selected,
            onChanged: _selectSession,
          ),
        ),
      ),
      body: SafeArea(
        child: registrants.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Gagal memuat senarai peserta.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(
                      activityRegistrantsProvider(widget.activityId),
                    ),
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (people) {
            if (people.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Belum ada pendaftaran untuk aktiviti ini.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () async {
                ref.invalidate(activityRegistrantsProvider(widget.activityId));
                await ref.read(
                  activityRegistrantsProvider(widget.activityId).future,
                );
                // Data baharu ialah kebenaran penuh; tindihan tempatan
                // yang kekal hanya boleh bercanggah dengannya.
                if (mounted) setState(_resetOverrides);
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: people.length,
                itemBuilder: (context, index) {
                  final person = people[index];
                  return _RegistrantTile(
                    person: person,
                    // Server dahulu, tindihan tempatan menang.
                    marked:
                        _marked[person.id] ??
                        (selected != null && person.attended(selected)),
                    busy:
                        selected != null &&
                        _busy.contains(_busyKey(selected, person.id)),
                    // Tiada sesi dipilih = tiada apa yang boleh ditanda.
                    // Suis dimatikan dan bukan gagal selepas ditekan.
                    onChanged: selected == null
                        ? null
                        : (v) => _setAttendance(person, v, selected),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SessionPicker extends StatelessWidget {
  const _SessionPicker({
    required this.sessions,
    required this.selectedId,
    required this.onChanged,
  });

  final List<ActivitySession> sessions;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text('Aktiviti ini belum ada sesi.'),
      );
    }

    // Dropdown, bukan cip mendatar: aktiviti berbilang sesi (kursus enam
    // minggu) menjadikan jalur cip perlu ditatal untuk mencari sesi ke-5,
    // sedangkan dropdown kekal satu ketukan tidak kira berapa banyak sesi.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: DropdownButtonFormField<String>(
        initialValue: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Sesi',
          isDense: true,
        ),
        items: [
          for (var i = 0; i < sessions.length; i++)
            DropdownMenuItem(
              value: sessions[i].id,
              child: Text(
                sessions[i].title.isNotEmpty
                    ? '${sessions[i].title} — ${formatDateTime(sessions[i].startsAt)}'
                    : 'Sesi ${sessions[i].seq} — ${formatDateTime(sessions[i].startsAt)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _RegistrantTile extends StatelessWidget {
  const _RegistrantTile({
    required this.person,
    required this.marked,
    required this.busy,
    required this.onChanged,
  });

  final ActivityRegistrant person;
  final bool marked;
  final bool busy;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(person.name),
      subtitle: Text(
        person.displayName.isEmpty
            ? person.memberId
            : '${person.memberId} · daftar ${formatDate(person.registeredAt)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : Switch.adaptive(value: marked, onChanged: onChanged),
    );
  }
}
