import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Kod QR check-in bagi satu pendaftaran.
///
/// [token] datang daripada `GET /me/activities` yang SUDAH dimuatkan —
/// widget ini tidak membuat sebarang panggilan rangkaian. Itu sengaja:
/// liputan di dewan/gelanggang selalunya teruk, dan ahli yang membuka
/// skrin sebelum sampai mesti tetap boleh menunjukkan kodnya di pintu.
class CheckinQr extends StatelessWidget {
  const CheckinQr({super.key, required this.token, this.size = 220});

  final String token;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Putih TEGAR, bukan warna daripada tema.
        //
        // Dalam mod gelap, permukaan tema adalah gelap dan modul QR hitam
        // di atasnya menjadi tidak dapat dibaca — pengimbas tidak nampak
        // apa-apa dan ahli dihalau di pintu. Latar dan modul dikunci di
        // sini supaya kontras tidak bergantung pada tetapan peranti.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: token,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
            semanticsLabel: 'Kod QR check-in',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tunjukkan QR ini kepada pengurusan untuk direkodkan hadir',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
