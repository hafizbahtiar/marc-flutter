import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/map/map_page.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';

void main() {
  testWidgets('halaman peta papar pemilih variant OSM', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const MapPage()),
    );
    await tester.pump();

    expect(find.text('Peta'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('3D'), findsOneWidget);
    expect(find.text('Terrain'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
  });

  testWidgets('ketuk chip 3D menukar sumber terpilih', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const MapPage()),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilterChip, '3D'));
    await tester.pump();

    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '3D'),
    );
    expect(chip.selected, isTrue);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Standard'))
          .selected,
      isFalse,
    );
  });

  testWidgets('initialType mengikut katalog, bukan hardcode OSM', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MapPage(initialType: MapTileType.terrain),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Terrain'))
          .selected,
      isTrue,
    );
  });

  testWidgets(
    'penanda dikunci tegak (rotate: true), kompas tersembunyi di utara',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const MapPage()),
      );
      await tester.pump();

      final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(layer.rotate, isTrue);
      expect(layer.markers.single.rotate, isTrue);
      expect(find.byTooltip('Utara ke atas'), findsNothing);
    },
  );
}
