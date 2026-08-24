import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/activities/checkin_qr.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('QR kekal hitam-atas-putih dalam mod GELAP', (tester) async {
    // Pengawal sebenar: latar bertema dalam mod gelap menjadikan modul
    // hitam mustahil diimbas, dan ahli dihalau di pintu.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(body: CheckinQr(token: 'tok-abc')),
      ),
    );

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    // `data` peribadi dalam qr_flutter - yang boleh (dan perlu) diperiksa
    // di sini ialah warnanya.
    expect(qr.backgroundColor, Colors.white);
    expect(qr.eyeStyle.color, Colors.black);
    expect(qr.dataModuleStyle.color, Colors.black);

    final panel = tester.widget<Container>(
      find
          .ancestor(of: find.byType(QrImageView), matching: find.byType(Container))
          .first,
    );
    expect((panel.decoration as BoxDecoration).color, Colors.white);
  });
}
