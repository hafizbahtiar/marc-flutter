import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/map/app_map.dart';
import 'package:marc/shared/ui/map/map_controls.dart';
import 'package:marc/shared/ui/map/map_page.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';
import 'package:marc/shared/ui/sheet/app_info_sheet.dart';

/// Keadaan terpilih bagi satu pilihan dalam sheet. `showAppActionSheet`
/// menanda pilihan semasa dengan ikon semak pada `trailing` ListTile,
/// jadi itu yang diperiksa - bukan `Semantics`.
bool selectedInSheet(WidgetTester tester, String label) {
  final tile = tester.widget<ListTile>(
    find.ancestor(of: find.text(label), matching: find.byType(ListTile)).first,
  );
  return tile.trailing != null;
}

MapControlButton controlButton(WidgetTester tester, String tooltip) {
  return tester.widget<MapControlButton>(
    find
        .ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(MapControlButton),
        )
        .first,
  );
}

String styleOf(WidgetTester tester) {
  return tester
      .widget<AppMapDebugHost>(find.byType(AppMapDebugHost))
      .styleString;
}

void main() {
  Future<void> pumpMap(
    WidgetTester tester, {
    MapTileType initialType = MapTileType.standard,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MapPage(initialType: initialType),
      ),
    );
    // Elak `pumpAndSettle` pada peta - PlatformView MapLibre boleh
    // tak pernah settle. Satu frame + post-frame `onMapReady`.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('kawalan peta dikumpul, bukan bertaburan', (tester) async {
    await pumpMap(tester);

    expect(find.byType(MapControlGroup), findsNWidgets(3));
    expect(find.byTooltip('Jenis peta'), findsOneWidget);
    expect(find.byTooltip('Zoom masuk'), findsOneWidget);
    expect(find.byTooltip('Zoom keluar'), findsOneWidget);
    expect(find.byTooltip('Lokasi saya'), findsOneWidget);
    expect(find.byTooltip('Tukar ke pandangan 3D'), findsOneWidget);
    expect(find.byTooltip('Utara ke atas'), findsNothing);
  });

  testWidgets('setiap kawalan penuhi sasaran sentuh 48dp Material', (
    tester,
  ) async {
    await pumpMap(tester);

    final buttons = find.byType(MapControlButton);
    expect(buttons, findsWidgets);
    for (final element in buttons.evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(
        size,
        const Size(kMapControlSize, kMapControlSize),
        reason: 'kawalan peta di bawah sasaran sentuh minimum',
      );
    }
  });

  testWidgets('butang layer buka bottom sheet jenis peta', (tester) async {
    await pumpMap(tester);

    expect(find.text('Jenis Peta'), findsNothing);

    await tester.tap(find.byTooltip('Jenis peta'));
    await tester.pumpAndSettle();

    expect(find.text('Jenis Peta'), findsOneWidget);
    for (final label in ['Standard', 'Bright', 'Terrain', 'Transport']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(selectedInSheet(tester, 'Standard'), isTrue);
    expect(selectedInSheet(tester, 'Terrain'), isFalse);
  });

  testWidgets('pilih dalam sheet menukar gaya MapLibre', (tester) async {
    await pumpMap(tester);

    expect(styleOf(tester), contains('liberty'));

    await tester.tap(find.byTooltip('Jenis peta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terrain'));
    await tester.pumpAndSettle();

    expect(
      styleOf(tester),
      contains('fiord'),
      reason: 'gaya MapLibre tak ikut pilihan dalam sheet',
    );
    expect(find.text('Jenis Peta'), findsNothing, reason: 'sheet patut tutup');
  });

  testWidgets('butang zoom hidup selepas peta sedia', (tester) async {
    await pumpMap(tester);

    expect(controlButton(tester, 'Zoom masuk').onPressed, isNotNull);
    expect(controlButton(tester, 'Zoom keluar').onPressed, isNotNull);
    expect(controlButton(tester, 'Lokasi saya').onPressed, isNotNull);
    expect(controlButton(tester, 'Tukar ke pandangan 3D').onPressed, isNotNull);
  });

  testWidgets('initialType mengikut katalog, bukan hardcode OSM', (
    tester,
  ) async {
    await pumpMap(tester, initialType: MapTileType.terrain);

    expect(styleOf(tester), contains('fiord'));

    await tester.tap(find.byTooltip('Jenis peta'));
    await tester.pumpAndSettle();
    expect(selectedInSheet(tester, 'Terrain'), isTrue);
  });

  testWidgets('transport papar atribusi kaya OSM dan MeMoMaps', (tester) async {
    await pumpMap(tester, initialType: MapTileType.transport);

    expect(find.byType(MapAttribution), findsOneWidget);
    final texts = tester
        .widget<MapAttribution>(find.byType(MapAttribution))
        .attributions
        .map((a) => a.text);
    expect(texts, containsAll(['OpenStreetMap contributors', 'MeMoMaps']));
    expect(find.byTooltip('Attributions'), findsOneWidget);
  });

  // Regresi: kedudukan pengguna DAHULUNYA `AppMapMarker` pada pemalar
  // `kDefaultMapCenter`. Itu punca dua pepijat sekaligus - pin tunjuk
  // pusat KL dan bukan pengguna, dan sebab penanda Flutter diunjur secara
  // async ia ketinggalan di belakang peta lalu menggigil/hilang semasa
  // pan. Titik pengguna mesti kekal di lapisan native.
  testWidgets('halaman tak guna penanda Flutter untuk lokasi', (tester) async {
    await pumpMap(tester);

    expect(
      tester.widget<AppMap>(find.byType(AppMap)).markers,
      isEmpty,
      reason: 'lokasi pengguna mesti lapisan native, bukan AppMapMarker',
    );
    expect(find.byIcon(Icons.location_on), findsNothing);
  });

  testWidgets('titik lokasi native mati sehingga kebenaran diberi', (
    tester,
  ) async {
    await pumpMap(tester);

    // Tiada plugin permission_handler dalam ujian widget, jadi kebenaran
    // tak pernah diberi - dan `showUserLocation` mesti kekal false, bukan
    // dihidup secara optimistik.
    expect(
      tester.widget<AppMap>(find.byType(AppMap)).showUserLocation,
      isFalse,
    );
  });

  // Jarum kompas berputar sepanjang gesture. Kalau sudutnya dihantar
  // sebagai `double`, setiap sudut baru membina semula butang penuh -
  // Tooltip, InkWell dan permukaan bayang kumpulan - berpuluh kali
  // sesaat. Listenable mengehadkan pembinaan semula kepada ikon sahaja.
  testWidgets('kompas terima sudut sebagai listenable, bukan double', (
    tester,
  ) async {
    await pumpMap(tester);

    expect(
      controlButton(tester, 'Zoom masuk').rotation,
      isNull,
      reason: 'butang bukan kompas tak patut dapat Transform langsung',
    );
  });

  testWidgets('butang 3D menawarkan 2D selepas ditekan', (tester) async {
    await pumpMap(tester);

    await tester.tap(find.byTooltip('Tukar ke pandangan 3D'));
    await tester.pump();

    expect(
      find.byTooltip('Tukar ke pandangan 2D'),
      findsOneWidget,
      reason: 'butang toggle mesti tunjuk tindakan seterusnya, bukan beku',
    );
    expect(find.byTooltip('Tukar ke pandangan 3D'), findsNothing);
  });

  testWidgets('atribusi overlay muncul hanya bila transport dipilih', (
    tester,
  ) async {
    await pumpMap(tester);

    List<String> attributionTexts() => tester
        .widget<MapAttribution>(find.byType(MapAttribution))
        .attributions
        .map((a) => a.text)
        .toList();

    expect(
      attributionTexts(),
      isNot(contains('data.gov.my')),
      reason: 'Standard tak guna data transit, jadi jangan kreditkannya',
    );

    await tester.tap(find.byTooltip('Jenis peta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();

    expect(attributionTexts(), containsAll(['data.gov.my', 'Prasarana']));
  });

  testWidgets('tekan atribusi buka sheet maklumat, bukan kembang inline', (
    tester,
  ) async {
    await pumpMap(tester, initialType: MapTileType.transport);

    expect(find.byType(AppInfoSheet), findsNothing);

    await tester.tap(find.byTooltip('Attributions'));
    await tester.pumpAndSettle();

    expect(find.byType(AppInfoSheet), findsOneWidget);
    expect(find.text('Sumber data'), findsOneWidget);
    expect(find.text('OpenStreetMap contributors'), findsOneWidget);

    // Transport ada lima penyedia; yang kemudian berada di bawah lipatan
    // pada saiz rehat dan SliverList membina secara malas. Inilah sebab
    // baris cip inline dulu terlalu sempit untuk kes ni.
    await tester.drag(find.text('Sumber data'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('data.gov.my'), findsOneWidget);
    expect(find.text('Prasarana'), findsOneWidget);
  });

  testWidgets('tutup sheet mengembalikannya, dan back menutupnya dahulu', (
    tester,
  ) async {
    await pumpMap(tester, initialType: MapTileType.transport);
    await tester.tap(find.byTooltip('Attributions'));
    await tester.pumpAndSettle();
    expect(find.byType(AppInfoSheet), findsOneWidget);

    // Kad bukan route, jadi tanpa PopScope back akan meninggalkan halaman
    // sementara kad masih terbuka di skrin.
    final popped = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(popped, isTrue, reason: 'back dimakan oleh kad, bukan halaman');
    expect(find.byType(AppInfoSheet), findsNothing);
  });
}
