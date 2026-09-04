import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/sheet/app_info_sheet.dart';

Future<void> pumpSheet(
  WidgetTester tester, {
  required VoidCallback onClose,
  String? subtitle,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Stack(
          children: [
            const Center(child: Text('kandungan di belakang')),
            AppInfoSheet(
              title: 'Tajuk',
              subtitle: subtitle,
              onClose: onClose,
              children: const [Text('butiran')],
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('kandungan di belakang kekal boleh dicapai - tiada barrier', (
    tester,
  ) async {
    await pumpSheet(tester, onClose: () {});
    await tester.pumpAndSettle();

    // Inilah seluruh sebab ia widget dalam Stack dan bukan modal: peta di
    // belakang mesti kekal boleh disentuh semasa kad dibaca. `hitTestable`
    // yang diperiksa, bukan ketiadaan ModalBarrier - MaterialApp sendiri
    // ada satu untuk routenya.
    expect(find.text('kandungan di belakang').hitTestable(), findsOneWidget);
    expect(find.text('Tajuk'), findsOneWidget);
  });

  testWidgets('butang tutup memanggil onClose', (tester) async {
    var closed = 0;
    await pumpSheet(tester, onClose: () => closed++);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tutup'));
    await tester.pump();

    expect(closed, 1);
  });

  testWidgets('subtitle ditinggalkan bila null', (tester) async {
    await pumpSheet(tester, onClose: () {}, subtitle: null);
    await tester.pumpAndSettle();
    expect(find.text('Tajuk'), findsOneWidget);

    await pumpSheet(tester, onClose: () {}, subtitle: 'baris kedua');
    await tester.pumpAndSettle();
    expect(find.text('baris kedua'), findsOneWidget);
  });

  testWidgets('leret turun melepasi ambang buang memanggil onClose', (
    tester,
  ) async {
    var closed = 0;
    await pumpSheet(tester, onClose: () => closed++);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Tajuk'), const Offset(0, 600));
    await tester.pump();

    expect(closed, greaterThan(0));
  });
}
