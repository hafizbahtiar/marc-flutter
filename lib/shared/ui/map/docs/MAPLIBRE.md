# MapLibre

Nota khusus `maplibre_gl` 0.27.0 - perkara yang menghabiskan masa untuk
ditemui, dan yang doknya tak beritahu terus.

## Mod platform view Android

`MapLibreMap.useHybridComposition`, ditetapkan melalui
`initMapPlatformView()` dalam `main.dart` **sebelum `runApp`**. Peta yang
sudah dibina kekal dengan mod asalnya. Tiada kesan pada iOS.

| Nilai | View | Maksudnya |
|-------|------|-----------|
| `false` (lalai MapLibre sejak 0.16) | `GLSurfaceView` melalui Virtual Display | Laluan render paling terus. Tapi Flutter kena pancar semula MotionEvent ke dalam display maya - punca lazim gesture peta terasa berat pada Android. |
| `true` | `TextureView` dikomposit Flutter | Kos render lebih tinggi. **Mematikan `onMapClick`** - lihat perangkap di bawah. |

Walaupun namanya, ia **bukan** "Hybrid Composition" Flutter - kedua-dua
nilai melalui `initAndroidView` dan Flutter pilih modnya sendiri.

Kita set **`false`**, dan itu bukan lagi pilihan bebas: `true` mematikan
`onMapClick` sepenuhnya (lihat perangkap di bawah). Tetapan itu satu-satunya
knob yang menyentuh kelancaran gesture, tetapi ia juga memutuskan sama ada
peta boleh diketik langsung - jadi ia tak boleh diflip tanpa menguji tap
atas peranti dalam pusingan yang sama.

## Gesture: putar lwn condong bertembung

Pada Android kedua-dua dikesan daripada pointer yang sama, jadi seretan dua
jari yang tak betul-betul menegak sering didaftar sebagai putaran juga. Ini
dalam SDK native; ia **tak boleh ditala dari Dart**.

`tiltGesturesEnabled` dan `rotateGesturesEnabled` sudah `true` secara lalai
- kita nyatakan eksplisit dalam `AppMap` supaya ia jadi sebahagian kontrak
dan tak hilang tanpa disedari. Ia juga parameter `AppMap`, jadi skrin yang
mengutamakan 3D boleh matikan putaran dan pertembungan itu hilang terus.

## Tilt

`CameraUpdate.tiltTo(double)` wujud. MapLibre hadkan pitch pada **60**.

`AppMapController.tiltTo` mengapit pada 0-60 sendiri. Tanpa apitan, keadaan
Dart menyimpan 90 sementara kamera native duduk pada 60, dan butang toggle
2D/3D jadi tak sepadan dengan peta.

`kMapTilt3D` ialah 50, bukan 60: pada 60 ufuk masuk ke dalam frame dan
jubin jauh jadi kabur.

`kMapTilt3DThreshold` (5 darjah) wujud sebab gesture dua jari boleh berhenti
pada nilai kecil bukan sifar - tanpa ambang, butang tunjuk "3D" untuk
condongan yang mata pun tak nampak.

## Lokasi pengguna

- `myLocationEnabled: true` menghidupkan komponen lokasi native.
- `myLocationRenderMode` mesti **`compass`**, bukan `normal`: pada iOS hanya
  mode itu yang benar-benar memaparkan titik pengguna. Doknya sebut ini
  sekali lalu dan mudah terlepas pandang.
- Kebenaran ialah tanggungjawab pemanggil. Set flag tanpa kebenaran cuma
  hasilkan peta tanpa titik (Android) atau prompt sistem mengejut (iOS).
- `onUserLocationUpdated` menolak fix bila ia tiba. **Guna ini**, jangan
  tinjau `requestMyLocationLatLng` berulang - tinjauan membazir round-trip
  channel dan tetap tak tahu bila fix pertama sampai.

## Perangkap: TextureView menelan ketikan

`useTextureView: true` melicinkan gesture tetapi **menghalang `onMapClick`
sepenuhnya** pada Android. Disahkan melalui eksperimen pada peranti: sifar
peristiwa klik sampai ke Dart dengan `true`, setiap ketikan sampai dengan
`false`. Pan dan zum terus berfungsi dalam kedua-dua mod, jadi kerosakan
ini senyap - peta terasa hidup sepenuhnya, cuma tak boleh diketik.

Sebab itu `initMapPlatformView` lalainya `useTextureView: false`. Kalau
gesture perlu dilicinkan semula, tap mesti diuji atas peranti dalam
pusingan yang sama.

## Perangkap: koordinat ketikan ialah piksel FIZIKAL pada Android

Titik dalam `onMapClick` berada dalam ruang piksel VIEW native - piksel
fizikal pada Android, mata logical pada iOS. Disahkan pada peranti 480dpi
(faktor 3.0, skrin 360dp lebar): koordinat x mencecah **426**, jauh
melepasi 360.

Jadi mana-mana ambang sasaran sentuh mesti didarab dengan
`devicePixelRatio` pada Android. Nilai 12 yang kelihatan seperti "saiz
jari" sebenarnya jadi ~4dp, kotak yang lebih kecil daripada bulatan yang
cuba dikenai - dan setiap tap terlepas. Lihat `kMapTapSlop`.

`queryRenderedFeaturesInRect` menerima ruang yang SAMA, jadi rect itu betul
selagi ambangnya diskalakan.

## Perangkap: label perlukan fontstack yang gaya itu sajikan

`SymbolLayerProperties` tanpa `textFont` jatuh ke lalai spesifikasi
MapLibre: `Open Sans Regular` / `Arial Unicode MS Regular`. Glyph
OpenFreeMap (`https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf`)
**tidak menyajikan kedua-duanya** - hanya `Noto Sans Regular`, `Bold` dan
`Italic`.

Kegagalannya senyap sepenuhnya: layer dipasang, tiada ralat, tiada label.
`MapSymbolStyle.font` lalainya `Noto Sans Regular` dan ada ujian yang
mengunci itu.

## Perangkap: `annotationConsumeTapEvents` tak boleh kosong

```dart
assert(annotationOrder.length <= 4),
assert(annotationConsumeTapEvents.length > 0);
```

`annotationOrder: const []` dibenarkan dan doknya panggil ia "a big
performance boost for android". `annotationConsumeTapEvents: const []`
akan **assert** dalam debug. Biar ia default.

## Kitaran hayat gaya

Sumber dan layer perlukan gaya yang sudah dimuat - pasang pada
`onStyleLoadedCallback`, bukan `onMapCreated`.

Menukar `styleString` membuatkan MapLibre **buang semua layer** dan tembak
semula callback itu. Jadi pemasangan semula overlay datang percuma, dan
itulah sebab `MapOverlay` tiada `remove()`: tiada apa nak dirobohkan, dan
laluan perobohan akan jadi kod mati yang terpesong.

## API yang disahkan wujud dalam 0.27.0

`addGeoJsonSource` · `addLineLayer` · `addCircleLayer` · `addSymbolLayer` ·
`removeLayer` · `removeSource` · `queryRenderedFeatures(point, layerIds,
filter)` · `onFeatureTapped` · `updateMyLocationTrackingMode` ·
`requestMyLocationLatLng` · `moveCamera` / `animateCamera`

## Ujian widget

`MapLibreMap` ialah PlatformView dan meletup tanpa method channel native
(`_channel` uninitialized). `AppMap` mengesan ujian widget dan menggantikan
`AppMapDebugHost` - `SizedBox.expand` yang mendedahkan `styleString` supaya
ujian boleh mengesahkan gaya mengikut sumber terpilih.

Jangan guna `pumpAndSettle` pada peta: PlatformView boleh tak pernah settle.
Guna `pump()` dua kali - satu frame, plus post-frame `onMapReady`.
