import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/widgets/image_grid_layout.dart';

Widget _host(int n) => MaterialApp(
  home: Scaffold(
    body: ImageGridLayout(
      tiles: [
        for (var i = 0; i < n; i++)
          ColoredBox(key: ValueKey('t$i'), color: Colors.blue),
      ],
    ),
  ),
);

void main() {
  // Susun atur dikongsi antara feed dan penggubah post - kalau ia
  // terpesong, pratonton semasa mengarang tak lagi padan dgn hasil.
  for (final n in [1, 2, 3, 4]) {
    testWidgets('$n jubin dirender semua', (tester) async {
      await tester.pumpWidget(_host(n));
      await tester.pump();
      for (var i = 0; i < n; i++) {
        expect(find.byKey(ValueKey('t$i')), findsOneWidget);
      }
    });
  }

  testWidgets('kosong tak render apa-apa', (tester) async {
    await tester.pumpWidget(_host(0));
    await tester.pump();
    expect(find.byType(AspectRatio), findsNothing);
  });

  // 3 gambar BUKAN grid seragam: satu tinggi di kiri, dua bertindan di
  // kanan. Itu sebab ia bukan GridView.
  testWidgets('3 jubin: kiri tinggi penuh, kanan bertindan', (tester) async {
    await tester.pumpWidget(_host(3));
    await tester.pump();

    final left = tester.getRect(find.byKey(const ValueKey('t0')));
    final topRight = tester.getRect(find.byKey(const ValueKey('t1')));
    final bottomRight = tester.getRect(find.byKey(const ValueKey('t2')));

    expect(left.height, greaterThan(topRight.height));
    expect(topRight.top, lessThan(bottomRight.top));
    expect(left.right, lessThanOrEqualTo(topRight.left));
  });

  testWidgets('nisbah bezakan satu gambar drpd berbilang', (tester) async {
    expect(ImageGridLayout.aspectRatioFor(1), 16 / 10);
    expect(ImageGridLayout.aspectRatioFor(2), 16 / 9);
    expect(ImageGridLayout.aspectRatioFor(4), 3 / 2);
  });
}
