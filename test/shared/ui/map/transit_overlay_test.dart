import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/ui/map/map_overlay.dart';
import 'package:marc/shared/ui/map/transit_overlay.dart';

class _RecordingStyle implements MapStyleController {
  final sources = <String, Map<String, dynamic>>{};
  final layerOrder = <String>[];
  final symbols = <MapSymbolStyle>[];

  @override
  Future<void> addGeoJsonSource(String id, Map<String, dynamic> g) async {
    sources[id] = g;
  }

  @override
  Future<void> addLineLayer(String s, String id, MapLineStyle style) async {
    layerOrder.add(id);
  }

  @override
  Future<void> addCircleLayer(String s, String id, MapCircleStyle style) async {
    layerOrder.add(id);
  }

  @override
  Future<void> addSymbolLayer(String s, String id, MapSymbolStyle style) async {
    layerOrder.add(id);
    symbols.add(style);
  }
}

/// Bundle dalam-ingatan supaya ujian tak bergantung pada aset sebenar -
/// ujian ini tentang pemasangan, bukan tentang data Rapid KL.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.values);

  final Map<String, String> values;

  @override
  Future<ByteData> load(String key) async {
    final value = values[key];
    if (value == null) throw FlutterError('aset tiada: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = values[key];
    if (value == null) throw FlutterError('aset tiada: $key');
    return value;
  }
}

const _lines =
    '{"type":"FeatureCollection","features":['
    '{"type":"Feature","properties":{"id":"KJ","color":"#D50032"},'
    '"geometry":{"type":"LineString","coordinates":[[101.1,3.1],[101.2,3.2]]}}]}';

const _stations =
    '{"type":"FeatureCollection","features":['
    '{"type":"Feature","properties":{"name":"BANGSAR","routes":["KJ"],'
    '"colors":["#D50032"],"color":"#D50032","interchange":false,"oku":true},'
    '"geometry":{"type":"Point","coordinates":[101.1,3.1]}}]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('memasang sumber dan layer dari aset', () async {
    final style = _RecordingStyle();
    await TransitOverlay(
      bundle: _FakeBundle({
        TransitOverlay.linesAsset: _lines,
        TransitOverlay.stationsAsset: _stations,
      }),
    ).install(style);

    expect(
      style.sources.keys,
      containsAll([
        TransitOverlay.linesSourceId,
        TransitOverlay.stationsSourceId,
      ]),
    );
    expect(
      style.layerOrder,
      [
        TransitOverlay.linesLayerId,
        TransitOverlay.stationsLayerId,
        TransitOverlay.labelsLayerId,
      ],
      reason:
          'garis dahulu, kemudian bulatan, kemudian label - kalau tidak '
          'stesen tertimbus di bawah garisnya sendiri',
    );
  });

  test('atribusi menamakan penyedia data', () {
    final texts = const TransitOverlay().attributions.map((a) => a.text);
    expect(texts, containsAll(['data.gov.my', 'Prasarana']));
  });

  test('TransitStation dihurai dari properties ciri', () {
    final station = TransitStation.fromProperties(const {
      'name': 'TITIWANGSA',
      'routes': ['AG', 'MR'],
      'colors': ['#e57200', '#84bd00'],
      'interchange': true,
      'oku': false,
    });

    expect(station.name, 'TITIWANGSA');
    expect(station.routes, ['AG', 'MR']);
    expect(station.colors, ['#e57200', '#84bd00']);
    expect(station.interchange, isTrue);
    expect(station.oku, isFalse);
  });

  test('TransitStation menerima properties berkod JSON', () {
    // queryRenderedFeatures memulangkan senarai sebagai String JSON pada
    // sesetengah platform, bukan List Dart.
    final station = TransitStation.fromProperties(const {
      'name': 'BANGSAR',
      'routes': '["KJ"]',
      'colors': '["#D50032"]',
      'interchange': 'false',
      'oku': 'true',
    });

    expect(station.routes, ['KJ']);
    expect(station.colors, ['#D50032']);
    expect(station.interchange, isFalse);
    expect(station.oku, isTrue);
  });

  test('label stesen minta fontstack yang OpenFreeMap sajikan', () async {
    final style = _RecordingStyle();
    await TransitOverlay(
      bundle: _FakeBundle({
        TransitOverlay.linesAsset: _lines,
        TransitOverlay.stationsAsset: _stations,
      }),
    ).install(style);

    // Lalai spesifikasi MapLibre ialah 'Open Sans Regular' / 'Arial Unicode
    // MS Regular', dan glyph OpenFreeMap TIDAK menyajikan kedua-duanya -
    // hanya Noto Sans Regular/Bold/Italic. Membiarkan medan ni kosong
    // bermakna layer dipasang tanpa ralat dan label tak pernah dilukis.
    expect(style.symbols.single.font, ['Noto Sans Regular']);
  });
}
