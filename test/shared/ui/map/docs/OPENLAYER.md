# Lapisan & Penyedia Terbuka

Basemap yang boleh dipilih, siapa yang menyajikannya, dan lapisan tambahan
yang dilukis di atasnya.

## Basemap (`MapTileType`)

Kesemuanya gaya vektor OpenFreeMap, dilukis oleh MapLibre. Tiada kunci API.

| Jenis | Gaya | Nota |
|-------|------|------|
| `standard` | `liberty` / `dark` | Satu-satunya yang bertukar ikut tema. |
| `bright` | `bright` | Dulu bernama `threeD`. Nama itu mengelirukan - ia tak pernah 3D. |
| `terrain` | `fiord` | maxZoom 17. |
| `transport` | `positron` | **Lihat amaran di bawah.** |

## Amaran: `transport` bukan gaya pengangkutan

`positron` ialah basemap kelabu minimum CARTO. Rawatan relnya:

- `railway` dicat `#dddddd` - kelabu nyaris ghaib
- `railway_transit` (subway/LRT/monorail) ada **`minzoom: 16`**, jadi ia
  tak wujud sehingga zum hampir paras jalan

Ia juga beri atribusi **MeMoMaps**, penyedia raster yang tak pernah diambil:
`AppMap._styleString` hanya baca `vectorStyleUri`, jadi `urlTemplate` dan
`subdomains` ialah kod mati (lihat `ARCHITECTURE.md`).

Layer `transport` menjadi bermakna hanya melalui overlay transit yang
terikat padanya.

## Overlay

Overlay ialah lapisan tambahan di ATAS basemap, dipasang pada gaya yang
sudah dimuat.

```dart
abstract interface class MapOverlay {
  String get id;
  List<MapTileAttribution> get attributions;
  Future<void> install(MapStyleController style);
}
```

`MapStyleController` ialah pembalut nipis milik kita yang dedahkan hanya
`addGeoJsonSource`, `addLineLayer`, `addCircleLayer`, `addSymbolLayer`.
**Overlay tak pernah nampak jenis MapLibre**, jadi ia diuji dengan double
yang merekod panggilan - tiada peta native diperlukan.

`MapTileSource.overlays` yang mengikatnya. `transport` pulangkan
`[TransitOverlay()]`; yang lain pulangkan `const []`. Satu baris itu sahaja
pengikatannya.

Struktur ini lebih daripada yang "lukis rel bila transport dipilih"
perlukan. Ia disengajakan: ia menjadikan pengikatan itu **konfigurasi**,
bukan komitmen. Menjadikan overlay satu toggle bebas kemudian bermakna
hantar `overlays` terus ke `AppMap` dan tambah satu butang - tiada apa
dalam `TransitOverlay` berubah.

Atribusi digabung secara automatik: `AppMap` cantumkan atribusi basemap
dengan atribusi setiap overlay terpasang, jadi kredit muncul tepat bila
overlay hidup dan hilang bersamanya.

## Overlay transit

Laluan rel Rapid KL dari GTFS data.gov.my - warna rasmi, geometri sebenar,
151 baris stesen digabung kepada 132. Lihat `TRANSPORTATION.md` untuk sumber
data, perangkap feed, dan cara jana semula.

Kenapa GTFS dan bukan menggaya semula jubin OSM: jubin ada geometri rel
tapi **tiada identiti laluan atau warna** - lihat `OSM.md`.

## Atribusi ialah keperluan lesen

Setiap penyedia perlukan kredit yang nampak dan boleh diketik. `AppMap`
memaparkannya melalui `MapAttribution` (butang hak cipta boleh kembang).
Jangan buang untuk "kebersihan visual" - ia syarat penggunaan, bukan hiasan.

Status lesen data.gov.my untuk edaran semula dalam APK **belum disahkan** -
lihat `TRANSPORTATION.md`.
