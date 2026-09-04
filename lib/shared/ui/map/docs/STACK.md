# Stack Peta

Apa yang dipasang, versi mana, dan kenapa.

## Kebergantungan

| Pakej | Versi | Peranan |
|-------|-------|---------|
| `maplibre_gl` | ^0.27.0 | Renderer peta native (Android/iOS/web). |
| `latlong2` | ^0.10.1 | `LatLng` - jenis koordinat awam modul ini. |
| `permission_handler` | 12.0.3 | Kebenaran lokasi. **Dipin**, lihat di bawah. |
| `url_launcher` | - | Pautan atribusi. |

Modul peta **tidak** guna `geolocator`. Titik lokasi datang dari komponen
lokasi native MapLibre (`myLocationEnabled`), yang tak perlukan pakej lokasi
berasingan dan tak boleh ketinggalan di belakang peta.

## Siling compileSdk

`permission_handler` dipin pada **12.0.3** dengan sengaja:
`permission_handler_android` 14.x perlukan compileSdk 37. `pubspec.yaml` ada
komen panjang tentang ini merentas beberapa pakej.

**Sebelum menambah mana-mana kebergantungan berkaitan lokasi/peta, periksa
compileSdk yang ia perlukan.** Ini sebab utama `geolocator` dielakkan:
ia berisiko menaikkan siling itu untuk faedah yang lapisan native sudah beri.

## Kebenaran

Android (`AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

COARSE disenarai bersama FINE sebab Android 12+ benarkan pengguna pilih
"Anggaran sahaja" - **tanpa COARSE, pilihan itu jadi penolakan penuh**.
Tiada `ACCESS_BACKGROUND_LOCATION`: peta hanya perlukan lokasi semasa skrin
terbuka.

iOS (`Info.plist`): `NSLocationWhenInUseUsageDescription` sahaja. Tiada
`NSLocationAlwaysAndWhenInUse` kerana tiada apa yang menjejak di latar.

Dalam kod: `Permission.locationWhenInUse`. Semak `.status` **dahulu**
sebelum `.request()` - bila kebenaran sudah ada, skrin patut terus fokus
pada pengguna tanpa apa-apa dialog.

## Aset

```yaml
assets:
  - assets/transit/rail_lines.geojson
  - assets/transit/rail_stations.geojson
```

Entri direktori Flutter **tidak rekursif**. `- assets/transit/` akan ambil
fail terus dalam direktori itu sahaja; setiap subdirektori kena disenarai
sendiri. `pubspec.yaml` sudah ada komen tentang perangkap ini.

## Alat

`tool/build_transit_assets.dart` - `dart run`, bukan sebahagian app. Muat
turun GTFS, sula, tulis GeoJSON. Lihat `TRANSPORTATION.md`.

## Ujian

`flutter test test/shared/ui/map`

Jangan `pumpAndSettle` peta - PlatformView boleh tak pernah settle. Lihat
`MAPLIBRE.md`.

## Isu build yang diketahui

`flutter build apk` melaporkan *"Gradle build failed to produce an .apk
file"* walaupun ia berjaya. Sebabnya flavor produk (`prod`/`staging`) -
APK memang ada di `build/app/outputs/flutter-apk/app-<flavor>-debug.apk`.
Guna `--flavor prod`, atau pasang terus dengan `adb install -r`.

Amaran KGP (`maplibre_gl`, `mobile_scanner`, `stripe_android` dan lain-lain
yang menggunakan Kotlin Gradle Plugin) tak berbahaya buat masa ini, tapi
versi Flutter akan datang akan gagal membina kerananya.
