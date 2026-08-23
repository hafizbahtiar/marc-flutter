import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/features/activities/activity_providers.dart';
import 'package:marc/features/activities/scan_result.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Kandungan QR venue - lihat komen keselamatan penuh di
/// `activity_attendance.go` Mark. Awalan ni SENGAJA supaya skrin ni
/// (dan bukan pengimbas pengurusan) yang cuba baca kod, mengelak
/// kekeliruan kalau seseorang imbas QR peribadi (checkin_token) di sini
/// secara silap - mesej ralat jelas nampak "bukan QR sesi", bukan
/// gagal senyap cuba panggil endpoint yang salah.
const _venueQrPrefix = 'marc-checkin:';

/// Pengimbas QR daftar hadir SENDIRI (`self_scan`) - utk AHLI BIASA,
/// bukan pengurusan. Beza penting drpd `CheckinScannerPage`
/// (pengurusan): skrin tu imbas QR PERIBADI ahli lain (checkin_token,
/// kelayakan pembawa); skrin ni imbas QR VENUE (data awam "sesi apa",
/// lihat `SessionCheckinQrPage`) dan hantar identiti PENGIMBAS SENDIRI
/// (drpd token JWT log masuk) ke server - tiada kelayakan pembawa
/// terlibat langsung, jadi tiada keperluan token berputar (rujuk
/// TODO.md sebelum ni).
///
/// Tiada parameter aktiviti/sesi - kedua-duanya datang drpd KANDUNGAN
/// QR yang diimbas, bukan konteks skrin. Backend tolak (409) kalau
/// pengimbas tak berdaftar utk aktiviti dlm QR tu.
class SelfCheckinScannerPage extends ConsumerStatefulWidget {
  const SelfCheckinScannerPage({super.key});

  @override
  ConsumerState<SelfCheckinScannerPage> createState() =>
      _SelfCheckinScannerPageState();
}

class _SelfCheckinScannerPageState
    extends ConsumerState<SelfCheckinScannerPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  final _debouncer = ScanDebouncer();
  ScanResult? _last;
  bool _busy = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    if (_debouncer.shouldSkip(code)) return;
    _debouncer.prune();

    if (!code.startsWith(_venueQrPrefix)) {
      setState(
        () => _last = const ScanResult(
          ScanResultKind.unknownCode,
          'Ini bukan QR daftar hadir. Imbas QR yang dipaparkan di venue.',
        ),
      );
      return;
    }
    final parts = code.substring(_venueQrPrefix.length).split(':');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      setState(
        () => _last = const ScanResult(
          ScanResultKind.unknownCode,
          'QR tidak sah. Cuba imbas semula.',
        ),
      );
      return;
    }

    setState(() => _busy = true);
    final result = await ref
        .read(activityRepositoryProvider)
        .selfCheckIn(activityId: parts[0], sessionId: parts[1]);
    if (!mounted) return;

    if (result.kind == ScanResultKind.network) {
      _debouncer.evict(code);
    }
    setState(() {
      _busy = false;
      _last = result;
    });
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    _debouncer.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Hadir Sendiri'),
        actions: [
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
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'Imbas QR yang dipaparkan pengurusan di venue.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: MobileScanner(
                controller: _controller,
                onDetect: (capture) => unawaited(_onDetect(capture)),
                onDetectError: (_, _) {},
                errorBuilder: (context, error) =>
                    _CameraError(error: error, controller: _controller),
              ),
            ),
            _ResultBanner(result: _last, busy: _busy),
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result, required this.busy});

  final ScanResult? result;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = result;

    final (
      Color background,
      Color foreground,
      IconData icon,
      String text,
    ) = switch (r?.kind) {
      null => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.qr_code_scanner,
        'Halakan kamera ke QR di venue.',
      ),
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
        r!.message,
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

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.controller});

  final MobileScannerException error;
  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;

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
                    ? 'Akses kamera diperlukan untuk mengimbas QR daftar '
                          'hadir. Benarkan kamera dalam Tetapan.'
                    : 'Kamera tidak dapat dimulakan. Cuba lagi.',
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
