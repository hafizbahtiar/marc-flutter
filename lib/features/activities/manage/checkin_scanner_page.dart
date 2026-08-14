import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/features/activities/activity_format.dart';
import 'package:marc/features/activities/activity_models.dart';
import 'package:marc/features/activities/activity_providers.dart';
import 'package:marc/features/activities/manage/manage_providers.dart';
import 'package:marc/features/activities/manage/management_gate.dart';
import 'package:marc/features/activities/manage/scan_result.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Pengimbas QR check-in untuk pengurusan.
///
/// SESI dipilih SEBELUM masuk ke sini (pada skrin Senarai Peserta) dan
/// dikunci pada route. Pemilih sesi di atas kamera akan bermakna satu
/// ketukan tersilap menanda 40 orang pada sesi yang salah, dan kehadiran
/// per-sesi ialah asas kiraan kelayakan sijil.
///
/// Check-in memerlukan rangkaian DENGAN SENGAJA — tiada baris gilir luar
/// talian. Tetingkap check-in dikuatkuasakan oleh jam SERVER; gilir pada
/// peranti boleh dimanipulasi dengan menukar jam telefon, dan kehadiran
/// ialah bukti yang menentukan siapa menerima sijil.
class CheckinScannerPage extends StatelessWidget {
  const CheckinScannerPage({
    super.key,
    required this.activityId,
    required this.sessionId,
  });

  final String activityId;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return ManagementGate(
      title: 'Imbas QR',
      child: _ScannerBody(activityId: activityId, sessionId: sessionId),
    );
  }
}

class _ScannerBody extends ConsumerStatefulWidget {
  const _ScannerBody({required this.activityId, required this.sessionId});

  final String activityId;
  final String sessionId;

  @override
  ConsumerState<_ScannerBody> createState() => _ScannerBodyState();
}

class _ScannerBodyState extends ConsumerState<_ScannerBody> {
  /// `formats` dihadkan kepada QR sahaja: apa-apa barcode lain di dalam
  /// bingkai (kod bar pada beg, tag nama) hanya boleh menjadi permintaan
  /// yang pasti gagal.
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  final _debouncer = ScanDebouncer();

  ScanResult? _last;

  /// Bilangan permintaan dalam penerbangan — sepanduk menunjukkan pemutar
  /// supaya pengurus tahu imbasan itu SEDANG dihantar dan tidak mengulang
  /// tanda secara manual di atasnya.
  int _inFlight = 0;

  /// Nombor urutan imbasan TERAKHIR yang dihantar. Lihat [_onDetect].
  int _seq = 0;

  /// Kamera KEKAL TERBUKA merentas imbasan.
  ///
  /// Tiada `context.pop()`, tiada dialog yang menghalang: barisan 40 orang
  /// bermakna 40 kali menekan "kembali" dan menunggu kamera dimulakan
  /// semula. Hasil dipapar sebagai sepanduk di bawah paparan, dan imbasan
  /// seterusnya boleh berlaku serta-merta.
  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    // `code` ialah checkin_token ahli. Ia TIDAK PERNAH dilog, tidak
    // dimasukkan ke dalam mesej ralat, dan tidak keluar dari fungsi ini
    // selain ke dalam badan permintaan HTTPS.
    if (code == null || code.isEmpty) return;
    if (_debouncer.shouldSkip(code)) return;
    // Token ahli lain tidak hidup dalam memori lebih lama daripada
    // tetingkap nyahlantun.
    _debouncer.prune();

    final seq = ++_seq;
    setState(() => _inFlight++);

    final result = await ref
        .read(activityManageRepositoryProvider)
        .checkInByToken(
          activityId: widget.activityId,
          sessionId: widget.sessionId,
          token: code,
        );

    if (!mounted) return;

    setState(() {
      _inFlight--;
      // Hasil LAMA yang mendarat lewat tidak menindih hasil imbasan yang
      // lebih baharu — kalau tidak, sepanduk akan mengesahkan orang yang
      // sudah beredar dari hadapan kamera.
      //
      // KEGAGALAN dikecualikan: ia sentiasa dipapar. Kegagalan yang
      // ditelan diam-diam kerana orang seterusnya sempat diimbas ialah
      // orang yang berjalan masuk tanpa direkodkan hadir.
      if (seq == _seq || result.isFailure) _last = result;
    });
  }

  @override
  void dispose() {
    // Kamera yang dibiarkan hidup ialah masalah bateri DAN privasi.
    // `dispose` pengawal ialah Future; `unawaited` kerana `State.dispose`
    // segerak dan tiada apa yang boleh dibuat dengan hasilnya di sini.
    unawaited(_controller.dispose());
    // Token check-in tidak hidup lebih lama daripada skrin yang membacanya.
    _debouncer.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions =
        ref
            .watch(activityDetailProvider(widget.activityId))
            .valueOrNull
            ?.sessions ??
        const <ActivitySession>[];
    // Detail aktiviti mungkin belum dimuat (masuk terus melalui pautan
    // dalam) — sesi null hanya menyembunyikan bar tajuk, ia TIDAK
    // menghalang imbasan: id sesi datang dari route dan sudah pasti.
    ActivitySession? session;
    for (final s in sessions) {
      if (s.id == widget.sessionId) {
        session = s;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Imbas QR'),
        actions: [
          // Lampu suluh: dewan yang malap ialah keadaan biasa untuk
          // majlis waktu malam, dan tanpa ini pengurus terpaksa keluar
          // skrin untuk menghidupkan lampu telefon.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'Matikan lampu' : 'Hidupkan lampu',
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                onPressed: state.isRunning
                    ? () => unawaited(_controller.toggleTorch())
                    : null,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (session != null) _SessionBar(session: session),
            Expanded(
              child: MobileScanner(
                controller: _controller,
                onDetect: (capture) => unawaited(_onDetect(capture)),
                // Ralat pengesanan (bingkai rosak, kod tidak boleh dibaca)
                // berlaku berpuluh kali sesaat pada cahaya yang lemah.
                // Ia BUKAN maklumat untuk pengurus dan tidak boleh
                // menyentuh sepanduk hasil.
                onDetectError: (_, _) {},
                errorBuilder: (context, error) =>
                    _CameraError(error: error, controller: _controller),
              ),
            ),
            _ResultBanner(result: _last, busy: _inFlight > 0),
          ],
        ),
      ),
    );
  }
}

class _SessionBar extends StatelessWidget {
  const _SessionBar({required this.session});

  final ActivitySession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = session.title.isNotEmpty
        ? session.title
        : 'Sesi ${session.seq}';

    // Sesi yang sedang ditanda dinyatakan SECARA JELAS dan berterusan.
    // Kehadiran adalah per-sesi; pengurus yang tidak nampak sesi mana yang
    // aktif tidak ada cara untuk perasan dia berada di skrin yang salah.
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        '$label — ${formatDateTime(session.startsAt)}',
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Sepanduk hasil — enam keadaan, dua daripadanya HIJAU.
///
/// "Sudah ditanda hadir" hijau kerana imbasan berulang ialah kelakuan
/// biasa: QR yang sama dipegang semula, atau dua pengurus mengimbas orang
/// yang sama. Merah di sini akan menyuruh pengurus mengimbas semula, atau
/// lebih teruk, menanda manual di atas kehadiran yang SUDAH wujud.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result, required this.busy});

  final ScanResult? result;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = result;

    final (Color background, Color foreground, IconData icon, String text) =
        switch (r?.kind) {
          null => (
            scheme.surfaceContainerHighest,
            scheme.onSurfaceVariant,
            Icons.qr_code_scanner,
            'Halakan kamera ke QR peserta.',
          ),
          // Dua keadaan hijau, perkataan berbeza.
          ScanResultKind.marked => (
            const Color(0xFF1B5E20),
            Colors.white,
            Icons.check_circle,
            r!.message,
          ),
          ScanResultKind.alreadyMarked => (
            const Color(0xFF2E7D32),
            Colors.white,
            Icons.done_all,
            r!.message,
          ),
          // Empat keadaan merah, ikon dan teks berbeza supaya pengurus
          // tahu tindakan mana yang tinggal: cari nama dalam senarai,
          // pinda kehadiran, minta QR yang betul, atau cuba lagi.
          ScanResultKind.notRegistered => (
            scheme.errorContainer,
            scheme.onErrorContainer,
            Icons.person_off,
            r!.message,
          ),
          ScanResultKind.outsideWindow => (
            scheme.errorContainer,
            scheme.onErrorContainer,
            Icons.schedule,
            '${r!.message} Guna Senarai Peserta untuk pindaan '
                '(sebab akan direkod).',
          ),
          ScanResultKind.unknownCode => (
            scheme.errorContainer,
            scheme.onErrorContainer,
            Icons.qr_code_2,
            r!.message,
          ),
          ScanResultKind.network => (
            scheme.errorContainer,
            scheme.onErrorContainer,
            Icons.wifi_off,
            r!.message,
          ),
        };

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Row(
        children: [
          if (busy)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(foreground),
              ),
            )
          else
            Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kamera tidak boleh dimulakan — hampir selalunya kebenaran ditolak.
///
/// `mobile_scanner` meminta kebenaran kamera sendiri semasa `start()`;
/// tiada permintaan berasingan di sini. Yang tinggal ialah keadaan
/// "ditolak selamanya", di mana satu-satunya jalan keluar ialah Tetapan —
/// dan skrin yang hanya memaparkan ikon ralat hitam ialah jalan mati.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.controller});

  final MobileScannerException error;
  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    final denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white70, size: 40),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'Akses kamera diperlukan untuk mengimbas QR kehadiran. '
                          'Benarkan kamera dalam Tetapan, atau tanda '
                          'kehadiran secara manual pada Senarai Peserta.'
                    : 'Kamera tidak dapat dimulakan. Tanda kehadiran secara '
                          'manual pada Senarai Peserta kalau ini berterusan.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              if (denied)
                OutlinedButton(
                  onPressed: () => unawaited(openAppSettings()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: const Text('Buka tetapan'),
                )
              else
                OutlinedButton(
                  onPressed: () => unawaited(controller.start()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: const Text('Cuba lagi'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
