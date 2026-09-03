# Modul Peta - Ujian & Dokumen

Ujian untuk `lib/shared/ui/map/`, dan dokumen rujukan modul itu.

```bash
flutter test test/shared/ui/map
```

## Dokumen

| Fail | Isi |
|------|-----|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Fail, sempadan, peraturan penanda Flutter lwn native, dan sebab kawalan tak dibina semula setiap frame. |
| [`docs/MAPLIBRE.md`](docs/MAPLIBRE.md) | Perangkap `maplibre_gl` 0.27: mod platform view Android, pertembungan gesture, tilt, lokasi pengguna, kitaran hayat gaya. |
| [`docs/OSM.md`](docs/OSM.md) | Apa yang ada dalam jubin vektor - rel **ada**, identiti laluan **tiada**. Cara memeriksa jubin sendiri. |
| [`docs/OPENLAYER.md`](docs/OPENLAYER.md) | Basemap yang boleh dipilih, konsep overlay, dan kenapa `transport` dulunya tak tunjuk pengangkutan. |
| [`docs/TRANSPORTATION.md`](docs/TRANSPORTATION.md) | **Dari mana laluan Rapid KL datang**, perangkap feed GTFS, dan cara jana semula aset. |
| [`docs/STACK.md`](docs/STACK.md) | Kebergantungan, siling compileSdk, kebenaran, aset, isu build. |

## Fail ujian

| Fail | Liputan |
|------|---------|
| `app_map_test.dart` | Gaya ikut sumber; keadaan tilt + apitan; penapisan siaran kamera; lalai `showUserLocation`. |
| `map_page_test.dart` | Susun atur kawalan, sasaran sentuh, sheet jenis peta, toggle 2D/3D, tiada penanda Flutter untuk lokasi. |
| `osm_tile_source_test.dart` | Setiap variant ada gaya + atribusi tersendiri. |

## Kalau anda ke sini kerana sesuatu terasa salah

**Peta terasa clunky / gesture lambat** → `docs/MAPLIBRE.md`, bahagian mod
platform view. Flip `initMapPlatformView(useTextureView:)` dahulu sebelum
apa-apa lain; ia knob tunggal yang menyentuh perkara itu.

**Sesuatu di atas peta menggigil atau hilang semasa pan** → anda guna
`AppMapMarker`. Ia diunjur secara async jadi ia sentiasa ketinggalan di
belakang peta. Lihat peraturan penanda dalam `docs/ARCHITECTURE.md`.

**Butang 2D/3D tak sepadan dengan peta** → tilt diapit pada 0-60; lihat
`docs/MAPLIBRE.md`.

**Titik lokasi tak muncul pada iOS** → `myLocationRenderMode` mesti
`compass`, bukan `normal`. Ya, betul-betul.

**Laluan MRT/LRT hilang atau silap** → `docs/TRANSPORTATION.md`. Kemungkinan
besar aset perlu dijana semula.
