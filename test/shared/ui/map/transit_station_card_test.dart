import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/map/transit_overlay.dart';
import 'package:marc/shared/ui/map/transit_station_card.dart';

/// Sheet bermula pada saiz peek dan `SliverList` membina secara malas, jadi
/// ujian mesti menariknya naik sebelum menegaskan kandungan di bawah lipatan.
Future<void> pumpCard(
  WidgetTester tester,
  TransitStation station, {
  bool expand = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Stack(
          children: [TransitStationCard(station: station, onClose: () {})],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (expand) {
    await tester.drag(find.text(station.name), const Offset(0, -600));
    await tester.pumpAndSettle();
  }
}

const _masjidJamek = TransitStation(
  name: 'MASJID JAMEK',
  routes: ['AG', 'KJ'],
  names: ['LRT Ampang Line', 'LRT Kelana Jaya Line'],
  colors: ['#e57200', '#D50032'],
  interchange: true,
  oku: true,
  lines: [
    TransitStationLine(
      route: 'AG',
      terminus: 'Sentul Timur',
      first: '06:18',
      last: {'MonFri': '23:43', 'Sat': '23:43'},
      frequency: {'MonFri': (3, 5), 'Sat': (5, 5)},
    ),
  ],
);

void main() {
  testWidgets('setiap laluan muncul SEKALI, dengan kod dan nama penuh', (
    tester,
  ) async {
    await pumpCard(tester, _masjidJamek);

    // Regresi: kad dulu menyenaraikan setiap laluan dua kali - sekali
    // sebagai cip, sekali lagi sebagai tajuk jadual.
    expect(find.text('LRT Ampang Line'), findsOneWidget);
    expect(find.text('LRT Kelana Jaya Line'), findsOneWidget);
    expect(find.text('AG'), findsOneWidget);
    expect(find.text('KJ'), findsOneWidget);
  });

  testWidgets('metadata jadi satu baris subtitle', (tester) async {
    await pumpCard(tester, _masjidJamek);
    expect(find.text('Pertukaran · 2 laluan · Akses OKU'), findsOneWidget);
  });

  testWidgets('hari, waktu dan kekerapan ialah lajur berasingan', (
    tester,
  ) async {
    await pumpCard(tester, _masjidJamek);

    expect(find.text('Ke Sentul Timur'), findsOneWidget);
    // Lajur, bukan satu ayat bersambung - mengimbas satu nilai hanya
    // berfungsi bila nilai itu berbaris.
    expect(find.text('Isnin - Jumaat'), findsOneWidget);
    expect(find.text('06:18 - 23:43'), findsNWidgets(2));
    expect(find.text('3-5 min'), findsOneWidget);
    // Kekerapan malar dipapar sebagai satu nombor, bukan '5-5'.
    expect(find.text('5 min'), findsOneWidget);
    // Ahad tiada dalam data, jadi ia tak patut dikarang.
    expect(find.text('Ahad'), findsNothing);
  });

  testWidgets('laluan tanpa jadual mengatakannya', (tester) async {
    await pumpCard(tester, _masjidJamek);
    // KJ ada dalam routes tapi tiada entri lines.
    expect(find.text('Jadual tidak tersedia.'), findsOneWidget);
  });

  testWidgets('waktu tren terakhir dilabel anggaran', (tester) async {
    await pumpCard(tester, _masjidJamek);
    // Tanpa label ni seseorang boleh terlepas tren terakhir kerana kad.
    expect(find.textContaining('anggaran'), findsOneWidget);
  });

  testWidgets('stesen bukan pertukaran tak mendakwa sebaliknya', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const TransitStation(
        name: 'X',
        routes: ['KJ'],
        names: ['LRT Kelana Jaya Line'],
        colors: ['#D50032'],
        interchange: false,
        oku: false,
      ),
      expand: false,
    );

    expect(find.text('Tiada akses OKU'), findsOneWidget);
    expect(find.textContaining('Pertukaran'), findsNothing);
  });

  testWidgets('warna cacat dari feed tak menjatuhkan kad', (tester) async {
    await pumpCard(
      tester,
      const TransitStation(
        name: 'ROSAK',
        routes: ['ZZ'],
        names: ['Laluan Tak Dikenali'],
        colors: ['bukan-warna'],
        interchange: false,
        oku: true,
      ),
    );

    expect(find.text('Laluan Tak Dikenali'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
