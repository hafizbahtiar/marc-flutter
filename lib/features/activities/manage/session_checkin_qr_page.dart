import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:marc/features/activities/manage/management_gate.dart';

/// QR PAPAR DI VENUE - ahli imbas QR ini SENDIRI (`SelfCheckinScannerPage`)
/// utk daftar hadir tanpa pengurusan perlu buat apa-apa. Kandungan QR
/// cuma "sesi mana" (`marc-checkin:{activityId}:{sessionId}`) - data
/// AWAM venue, BUKAN kelayakan peribadi sesiapa. Identiti ahli yang
/// mengimbas datang drpd akaun log masuk MEREKA sendiri di sisi
/// pelayan - tangkapan skrin QR ni tidak berguna kepada sesiapa selain
/// "sesi apa nak daftar hadir", jadi ia selamat dipaparkan/dicetak
/// terbuka tanpa risiko kelayakan pembawa (lihat komen penuh
/// `activity_attendance.go` Mark).
class SessionCheckinQrPage extends StatelessWidget {
  const SessionCheckinQrPage({
    super.key,
    required this.activityId,
    required this.sessionId,
  });

  final String activityId;
  final String sessionId;

  String get _qrData => 'marc-checkin:$activityId:$sessionId';

  @override
  Widget build(BuildContext context) {
    return ManagementGate(
      title: 'QR Daftar Hadir',
      child: Scaffold(
        appBar: AppBar(title: const Text('QR Daftar Hadir')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Putih tegar - sama rasional dgn CheckinQr (QR
                  // peribadi ahli): modul QR hitam di atas latar gelap
                  // mod gelap tak terbaca kamera.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 280,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                      semanticsLabel: 'Kod QR daftar hadir sesi',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Paparkan QR ini di venue. Ahli imbas sendiri untuk '
                    'daftar hadir - tak perlu pengurusan imbas satu-satu.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
