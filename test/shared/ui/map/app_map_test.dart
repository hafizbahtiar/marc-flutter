import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/map/app_map.dart';
import 'package:marc/shared/ui/map/map_overlay.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';

void main() {
  testWidgets('tukar sumber menukar styleString MapLibre', (tester) async {
    const sourceA = _FakeSource(id: 'a', vectorUri: 'https://example.com/a');
    const sourceB = _FakeSource(id: 'b', vectorUri: 'https://example.com/b');

    Future<void> pumpSource(MapTileSource source) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: AppMap(tileSource: source)),
        ),
      );
    }

    await pumpSource(sourceA);
    await tester.pump();
    expect(
      tester.widget<AppMapDebugHost>(find.byType(AppMapDebugHost)).styleString,
      'https://example.com/a',
    );

    await pumpSource(sourceB);
    await tester.pump();
    expect(
      tester.widget<AppMapDebugHost>(find.byType(AppMapDebugHost)).styleString,
      'https://example.com/b',
      reason: 'gaya MapLibre mesti ikut sumber yang baru dipilih',
    );
  });

  test('tilt bermula pada 2D', () {
    final controller = AppMapController();
    addTearDown(controller.dispose);

    expect(controller.tilt, 0);
  });

  test('tiltTo mengapit pada julat yang MapLibre terima', () async {
    final controller = AppMapController();
    addTearDown(controller.dispose);

    // Tanpa apitan, keadaan Dart menyimpan 90 sementara kamera native
    // duduk pada 60 - dan butang toggle jadi tak sepadan dengan peta.
    await controller.tiltTo(90);
    expect(controller.tilt, kMapMaxTilt);

    await controller.tiltTo(-10);
    expect(controller.tilt, 0);
  });

  test('tiltTo lapor perubahan melalui mapEventStream', () {
    final controller = AppMapController();
    addTearDown(controller.dispose);

    expectLater(controller.mapEventStream, emits(anything));
    unawaited(controller.tiltTo(kMapTilt3D));
    expect(controller.tilt, kMapTilt3D);
  });

  test('gerakan kamera yang tak dapat dilihat tidak disiarkan', () async {
    final controller = AppMapController();
    addTearDown(controller.dispose);

    var events = 0;
    controller.mapEventStream.listen((_) => events++);
    await controller.move(const LatLng(3.0, 101.0), 15);
    await pumpEventQueue();
    final baseline = events;

    // MapLibre hantar `onCameraMove` setiap frame semasa gesture, selalu
    // dengan delta sekecil ni. Menyiarkan setiap satu memaksa setiap
    // pendengar bina semula UI 60-120 kali sesaat - itulah yang buat
    // kawalan peta terasa berat.
    for (var i = 0; i < 20; i++) {
      controller.debugSyncCamera(
        center: LatLng(3.0 + i * 1e-9, 101.0),
        zoom: 15 + i * 1e-5,
        bearing: i * 1e-3,
        tilt: i * 1e-3,
      );
    }
    await pumpEventQueue();

    expect(events, baseline, reason: 'delta sub-piksel patut ditapis');

    // Tapi getter mesti tetap terkini - menapis siaran bukan bermakna
    // membiarkan keadaan basi.
    expect(controller.zoom, closeTo(15 + 19e-5, 1e-9));
  });

  test('gerakan kamera yang ketara tetap disiarkan', () async {
    final controller = AppMapController();
    addTearDown(controller.dispose);

    var events = 0;
    controller.mapEventStream.listen((_) => events++);
    controller.debugSyncCamera(
      center: kDefaultMapCenter,
      zoom: kDefaultMapZoom,
      bearing: 45,
      tilt: 0,
    );
    await pumpEventQueue();

    expect(events, 1);
  });

  testWidgets('showUserLocation lalai mati', (tester) async {
    // Lokasi ialah kebenaran runtime: AppMap tak boleh minta ia secara
    // lalai untuk setiap pemanggil.
    const map = AppMap(
      tileSource: _FakeSource(id: 'a', vectorUri: 'https://example.com/a'),
    );

    expect(map.showUserLocation, isFalse);
  });
}

class _FakeSource implements MapTileSource {
  const _FakeSource({required this.id, required this.vectorUri});

  @override
  final String id;
  final String vectorUri;

  @override
  String get label => id;

  @override
  IconData get icon => Icons.map_outlined;

  @override
  String get urlTemplate => 'https://example.com/$id/{z}/{x}/{y}.png';

  @override
  List<String> get subdomains => const [];

  @override
  int get minZoom => 0;

  @override
  int get maxZoom => 19;

  @override
  String get attribution => 'test';

  @override
  List<MapTileAttribution> get attributions => [
    MapTileAttribution(attribution),
  ];

  @override
  String? vectorStyleUri(Brightness brightness) => vectorUri;

  @override
  List<MapOverlay> get overlays => const [];
}
