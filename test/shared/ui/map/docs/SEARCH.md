# Carian Tempat

Cara carian peta berfungsi, dan kenapa ia guna Photon dan bukan Nominatim.

## Photon, bukan Nominatim

`https://photon.komoot.io/api/` - data OSM, tiada kunci API, direka khas
untuk carian sambil-menaip.

**Nominatim tak boleh diguna untuk ini.** Dasar OSMF menyenaraikan
auto-complete di bawah *Unacceptable Use*, dengan perkataan mereka sendiri:

> **Auto-complete search** - This is not yet supported by Nominatim and you
> must not implement such a service on the client side using the API.
> ... strictly forbidden and will get you banned

Dasar itu juga sebut *"periodic requests from apps are considered bulk
geocoding and as such are strongly discouraged"*. Nominatim hanya sesuai
untuk carian tekan-enter dengan had 1 permintaan sesaat dan User-Agent
sebenar - bukan apa yang skrin ni buat.

Jangan tukar ke Nominatim untuk "hasil lebih baik". Ia akan mengharamkan
IP app.

| | Nominatim | Photon |
|---|---|---|
| Taip-sambil-cari | Diharamkan | Direka untuknya |
| Kunci API | Tiada | Tiada |
| Laju (ujian KL) | 0.34s | 1.86s |
| Availability | Tiada jaminan | **Tiada jaminan** |

## Terma Photon

> "You can use the API for your project, but please be fair - extensive
> usage will be throttled. We do not guarantee for the availability and
> usage might be subject of change in the future."

Tiga perkara mengikat reka bentuk:

1. **Nyahlantun 350ms + minimum 3 aksara.** Satu permintaan setiap ketukan
   kekunci bukan "berlaku adil".
2. **Gagal ialah keadaan biasa, bukan kes tepi.** Tiada jaminan
   availability bermakna timeout, 429 dan 5xx semuanya akan berlaku. Setiap
   satu berakhir sebagai ayat dalam senarai hasil, bukan ranap atau senyap.
3. **Ia boleh hilang.** Kalau Photon ditarik, `PlaceSearchService` ialah
   satu fail dan satu antara muka untuk diganti.

## Photon menyekat User-Agent stok pustaka

Dio pada Android menghantar `Dart/3.9 (dart:io)` secara lalai, dan Photon
memulangkan **403** untuknya. Diukur:

| User-Agent | Status |
|---|---|
| `Dart/3.9 (dart:io)` | **403** |
| `curl/8.7.1` | 200 |
| tiada UA | 200 |
| `marc/1.0 (+com.hafizbahtiar.marc)` | 200 |

Sebab itu `kPlaceSearchUserAgent` wujud dan diset pada BaseOptions dan
setiap permintaan. Membuangnya mematikan carian sepenuhnya, dengan 403
yang tak menyebut sebabnya.

Menamakan app juga betul dari segi kesopanan: penyedia terbuka perlu tahu
siapa yang memanggil supaya mereka boleh hubungi pemilik dan bukan sekadar
memblok IP.

## Klien Dio berasingan - JANGAN guna semula `api_client.dart`

`PlaceSearchService` mencipta `Dio`nya sendiri. `api_client.dart` membawa
interceptor auth; menggunakannya semula di sini akan menghantar token sesi
pengguna ke komoot pada setiap ketukan kekunci.

## Hasil Photon bukan stesen kita

Carian memulangkan tempat OSM, bukan objek `TransitStation`. Untuk membuka
kad jadual penuh, hasil dipadankan semula ikut **jarak**: `matchStation()`
memulangkan stesen dalam `kStationMatchMetres` (150 m), jika tidak null.

Tanpa had jarak itu, setiap carian akan membuka kad stesen rawak yang
kebetulan paling hampir.

Properties stesen dibaca sekali daripada aset semasa halaman dimuat, bukan
disoal semula daripada peta selepas kamera bergerak - soalan begitu
berlumba dengan renderer dan gagal bila layer belum sempat dilukis.

## Nyahduplikasi: nod pengangkutan sahaja, bukan ambang jarak

OSM memetakan satu stesen sebagai beberapa nod - station, stop, bus_stop,
entrance - dan Photon memulangkan kesemuanya. "Batu Caves" datang sebagai
empat baris serupa; "KLCC" pun sama.

Godaan pertama ialah menggabungkan apa-apa yang bernama sama dalam jarak
X. **Itu salah**, dan data sebenar menunjukkan sebabnya:

| Pertanyaan | Hasil bernama sama | Jarak |
|---|---|---|
| batu caves | 4 nod pengangkutan | 4-263 m |
| klcc | 4 nod pengangkutan | 7-380 m |
| starbucks bangsar | 5 kafe BERBEZA | **105**-1548 m |

Ambang yang cukup besar untuk menggabungkan peron stesen (400 m) juga akan
menggabungkan dua Starbucks yang 105 m berasingan, dan menyembunyikan
sebuah kedai sebenar daripada pengguna.

Jadi `dedupeTransportNodes()` hanya menggabungkan hasil yang **kedua-duanya
nod pengangkutan** (`PlaceResult.isTransportNode`), bernama sama, dalam
`kTransportDedupeMetres`. Tempat biasa tak pernah digabung. Yang paling
spesifik menang isinya (station > halt > stop) dan susunan Photon
dikekalkan.

Perhatikan `highway/residential` ialah jalan, bukan perhentian -
`isTransportNode` menyemak `osm_value` dan bukan `osm_key` sahaja.

## Ikon perlukan osm_key DAN osm_value

Versi pertama fungsi ikon menyuis pada `osm_value` sahaja, dan memadankan
`mosque` - nilai yang tak pernah wujud. Masjid ialah
`amenity/place_of_worship` dalam OSM. Kebanyakan hasil jatuh ke pin generik.

`station` juga bermakna lain di bawah `railway` berbanding `aeroway`. Padan
kedua-dua medan.

## Pengawal generasi

`MapSearchController._generation` bertambah setiap pertanyaan. Jawapan yang
tiba selepas pertanyaan lebih baru dibuang; tanpanya, respons perlahan
untuk "kl" boleh mendarat selepas "klcc" dan menggantikan apa yang pengguna
sedang lihat.

## Atribusi

Hasil Photon ialah data OSM. Kredit "Photon" ditambah ke dalam sheet sumber
data bila ia dibuka.
