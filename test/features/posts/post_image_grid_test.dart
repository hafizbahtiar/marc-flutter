import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/posts/widgets/post_image_grid.dart';
import 'package:marc/shared/ui/media/app_network_image.dart';
import 'package:marc/shared/ui/media/image_viewer_page.dart';

List<String> _urls(int n) =>
    List.generate(n, (i) => 'https://pub-test.r2.dev/posts/img$i.jpg');

Widget _host(List<String> urls) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: ListView(children: [PostImageGrid(urls: urls)]),
  ),
);

void main() {
  // Susunan gaya Twitter: bilangan gambar tentukan bentuk grid, jadi
  // setiap kiraan ialah laluan kod berasingan.
  for (final n in [1, 2, 3, 4]) {
    testWidgets('$n gambar → $n jubin dirender', (tester) async {
      await tester.pumpWidget(_host(_urls(n)));
      await tester.pump();

      expect(find.byType(AppNetworkImage), findsNWidgets(n));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('senarai kosong tak render apa-apa', (tester) async {
    await tester.pumpWidget(_host(const []));
    await tester.pump();
    expect(find.byType(AppNetworkImage), findsNothing);
  });

  // Grid mesti tak mengembang tanpa had dalam ListView - ia dihadkan oleh
  // AspectRatio, bukan saiz semula jadi gambar (yang tak diketahui sebelum
  // dimuat turun).
  testWidgets('grid ada tinggi terhad walau gambar belum dimuat', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_urls(4)));
    await tester.pump();

    final size = tester.getSize(find.byType(PostImageGrid));
    expect(size.height, greaterThan(0));
    expect(size.height, lessThan(size.width)); // 3:2 utk 4 gambar
  });

  testWidgets('ketuk jubin buka pemapar skrin penuh pada indeks itu', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_urls(3)));
    await tester.pump();

    await tester.tap(find.byType(AppNetworkImage).at(2));
    // pump() berjadual, bukan pumpAndSettle(): spinner "memuat" berpusing
    // selama-lamanya dalam ujian (gambar rangkaian tak pernah selesai),
    // jadi pumpAndSettle takkan pernah kembali.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final viewer = tester.widget<ImageViewerPage>(find.byType(ImageViewerPage));
    expect(viewer.initialIndex, 2);
    expect(viewer.urls, hasLength(3));
  });

  // Tag Hero mesti unik setiap URL - tag berulang dalam satu pokok
  // menyebabkan Flutter tegaskan ralat semasa peralihan.
  testWidgets('setiap jubin ada tag Hero unik', (tester) async {
    await tester.pumpWidget(_host(_urls(4)));
    await tester.pump();

    final tags = tester
        .widgetList<Hero>(find.byType(Hero))
        .map((h) => h.tag)
        .toList();
    expect(tags.toSet(), hasLength(tags.length));
  });

  // Regresi: `/feed` berada dalam StatefulShellRoute (shell + bottom nav
  // bar) manakala `/posts/:id` route peringkat atas. `Navigator.of(context)`
  // tanpa `rootNavigator: true` menyelesai ke navigator berlainan di
  // kedua-dua tempat, jadi pemapar dibuka DALAM shell bila dilancarkan dari
  // feed - bar navigasi kekal nampak, tinggi mengecil, dan kaunter
  // kanan-atas beralih. Mesti skrin penuh di mana-mana ia dibuka.
  testWidgets('pemapar skrin penuh walau dibuka dari navigator bersarang', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          // Meniru shell: kandungan + bar bawah, dengan Navigator sendiri.
          body: Column(
            children: [
              Expanded(
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: ListView(children: [PostImageGrid(urls: _urls(2))]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 80, child: ColoredBox(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(AppNetworkImage).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final screen = tester.getSize(find.byType(MaterialApp));
    final viewer = tester.getSize(find.byType(ImageViewerPage));
    expect(
      viewer.height,
      screen.height,
      reason: 'pemapar terkurung dalam navigator bersarang, bukan skrin penuh',
    );
  });

  // Kawalan putih atas gambar sembarangan tak boleh dibaca tanpa skrim/
  // latar - sebab "counter jadi buruk". Kekalkan latar tu.
  testWidgets('kawalan pemapar ada latar kontras, bukan teks kosong', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_urls(3)));
    await tester.pump();
    await tester.tap(find.byType(AppNetworkImage).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Kaunter dibalut kapsul legap separa, bukan Text bogel.
    final counter = find.text('1 / 3');
    expect(counter, findsOneWidget);
    final pill = tester.widget<Container>(
      find.ancestor(of: counter, matching: find.byType(Container)).first,
    );
    final decoration = pill.decoration! as BoxDecoration;
    expect(decoration.color!.a, greaterThan(0));
    expect(decoration.borderRadius, isNotNull);

    // Butang tutup 40dp (sasaran sentuh) dan berlatar.
    expect(
      tester.getSize(find.byIcon(Icons.close)).width,
      lessThanOrEqualTo(40),
    );
    expect(find.byType(Material), findsWidgets);
  });

  testWidgets('kaunter disorok bila post cuma ada satu gambar', (tester) async {
    await tester.pumpWidget(_host(_urls(1)));
    await tester.pump();
    await tester.tap(find.byType(AppNetworkImage).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining(' / '), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  // "Double line under text": Text tanpa moyang Material mewarisi
  // DefaultTextStyle fallback Flutter, yang membawa garis bawah BERGANDA
  // KUNING. Warna kita menimpa `color` tapi bukan `decoration`, jadi
  // hiasan ralat tu terus terpakai.
  testWidgets('teks pemapar tiada hiasan garis bawah', (tester) async {
    await tester.pumpWidget(_host(_urls(3)));
    await tester.pump();
    await tester.tap(find.byType(AppNetworkImage).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final paragraph = tester.renderObject<RenderParagraph>(find.text('1 / 3'));
    final style = paragraph.text.style!;
    expect(
      style.decoration ?? TextDecoration.none,
      TextDecoration.none,
      reason: 'kaunter dilukis dengan garis bawah ralat Flutter',
    );
  });
}
