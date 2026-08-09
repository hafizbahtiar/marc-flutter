import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/donation/widgets/duitnow_qr_card.dart';

Widget _host() => MaterialApp(
  theme: AppTheme.light,
  home: const Scaffold(body: SingleChildScrollView(child: DuitNowQrCard())),
);

void main() {
  testWidgets('papar QR + butang simpan', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.text('DuitNow QR'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Simpan QR ke galeri'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Bayaran QR memintas backend sepenuhnya — tiada baris donations, tiada
  // resit. Pengguna yang menjangka resit dan tak menerimanya akan fikir
  // duit mereka hilang, jadi amaran ni mesti kekal.
  testWidgets('nyatakan dengan jelas tiada resit automatik', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(
      find.textContaining('tiada resit automatik'),
      findsOneWidget,
      reason: 'amaran resit hilang',
    );
    expect(find.textContaining('Tiada yuran'), findsOneWidget);
  });

  // Aset mesti benar-benar wujud dan boleh dinyahkod — kalau tersalah nama
  // atau tak didaftar dalam pubspec, errorBuilder akan tunjuk teks ganti.
  testWidgets('aset QR dimuat, bukan fallback ralat', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('QR tidak dapat dimuat.'), findsNothing);

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(provider.assetName, 'assets/donation/maybank_hafiz.jpeg');
  });

  testWidgets('QR dihadkan lebarnya supaya butang kekal kelihatan', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    final qr = tester.getSize(find.byType(Image));
    expect(qr.width, lessThanOrEqualTo(260));
  });
}
