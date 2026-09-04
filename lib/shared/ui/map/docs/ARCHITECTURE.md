# Seni Bina Modul Peta

Fail dalam `lib/shared/ui/map/`, siapa milik apa, dan sempadan yang sengaja
diletakkan.

## Fail

| Fail | Tanggungjawab |
|------|---------------|
| `app_map.dart` | Widget peta + `AppMapController`. Satu-satunya tempat jenis MapLibre disentuh. |
| `map_controls.dart` | `MapControlGroup`, `MapControlButton`. Bahasa visual kawalan. |
| `map_tile_source.dart` | Kontrak: `MapTileSource`, `MapTileCatalog`, `MapTileAttribution`. Tiada import MapLibre. |
| `osm_tile_source.dart` | Pelaksanaan OSM/OpenFreeMap bagi kontrak itu. |
| `map_page.dart` | Halaman ujian. Bukan skrin produk. |

## Sempadan: MapLibre berhenti di `app_map.dart`

`map_tile_source.dart` tak import MapLibre langsung. Ia bercakap tentang
URI gaya, atribusi dan had zum - konsep yang kekal benar walaupun renderer
ditukar. `app_map.dart` yang menterjemah ke `MapLibreMap`.

Sebab itu `AppMapController` membalut `MapLibreMapController` dan bukan
mendedahkannya: pemanggil gerakkan kamera melalui `move`/`zoomBy`/`rotate`/
`tiltTo` dan tak pernah lihat `CameraUpdate`.

Sempadan yang sama berlaku pada overlay. `MapOverlay` terima
`MapStyleController` - pembalut nipis milik kita - bukan pengawal native,
jadi overlay boleh diuji dengan double yang merekod panggilan, tanpa peta.

## Penanda: Flutter lwn native

Dua cara meletak sesuatu atas peta, dan pilihan itu penting.

**`AppMapMarker`** ialah widget Flutter. Kedudukan skrinnya dikira melalui
`toScreenLocation` - satu round-trip async melalui platform channel - jadi
ia sentiasa satu frame atau lebih **di belakang** peta native semasa
pan/zoom. Ia menggigil, dan hilang sekejap bila unjuran gagal.

**Lapisan native** (titik lokasi, layer overlay) dilukis oleh MapLibre dalam
frame yang sama dengan jubin. Ia tak boleh ketinggalan.

Peraturan: apa-apa yang mesti melekat tepat pada peta - lokasi peranti
terutamanya - guna lapisan native. `AppMapMarker` untuk penanda statik yang
boleh terima sedikit lag.

Kedudukan pengguna dulunya `AppMapMarker` pada pemalar `kDefaultMapCenter`.
Itu punca dua pepijat sekaligus: pin tunjuk pusat KL dan bukan pengguna,
dan ia menggigil/hilang semasa pan. Sekarang ia `AppMap.showUserLocation`,
iaitu lapisan lokasi native MapLibre.

## Prestasi: jangan bina semula setiap frame

MapLibre panggil `onCameraMove` **setiap frame** semasa gesture, dengan
perubahan sekecil 0.001 darjah. Tiga perkara melindungi daripada itu:

**1. `AppMapController` menapis siaran.** Getter sentiasa terkini, tapi
`mapEventStream` hanya menyiar bila satu paksi berubah melebihi ambang
yang boleh dilihat (~0.1 m, 0.01 zum, 0.25 darjah). Delta sub-piksel -
majoriti mutlak - tak mencetuskan apa-apa.

**2. Pendengar simpan boolean, bukan darjah.** `map_page.dart` tulis
`_compassVisible` dan `_is3D`, bukan sudut mentah. `ValueNotifier` senyap
bila nilai sama, jadi permukaan `Material` berbayang dibina semula beberapa
kali **seumur skrin**, bukan beberapa kali sesaat.

**3. `MapControlButton.rotation` ialah `ValueListenable`, bukan `double`.**
Jarum kompas mesti berputar berterusan; listenable mengehadkan pembinaan
semula kepada ikon sahaja, bukan Tooltip + InkWell + bayang kumpulan.

Juga: `annotationOrder: const []` (dok MapLibre panggil ini "a big
performance boost for android" - kita tak guna anotasi), dan
`_projectMarkers` tak dipanggil langsung bila senarai penanda kosong.

## Mod platform view Android

`initMapPlatformView()` dalam `main.dart`, sebelum `runApp`. Lihat
`MAPLIBRE.md` - ia knob tunggal yang menyentuh kelancaran gesture, dan mana
satu lebih laju bergantung pada GPU peranti.

## Kod mati yang diketahui

`MapTileSource.urlTemplate` dan `.subdomains` **tak dibaca oleh sesiapa**.
`AppMap._styleString` hanya guna `vectorStyleUri`. Kedua-duanya sisa era
`flutter_map` sebelum tukar ke MapLibre. Ia selamat dibuang; ujian yang
menyentuhnya perlu dikemas sekali.
