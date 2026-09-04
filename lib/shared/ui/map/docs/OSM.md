# OpenStreetMap & Jubin Vektor

Data apa yang ada dalam jubin yang kita sudah muat turun, dan apa yang tiada.

## Skema

OpenFreeMap menyajikan jubin skema **OpenMapTiles**, `maxzoom: 14`
(overzoom di luar itu dilakukan klien). TileJSON:
`https://tiles.openfreemap.org/planet`.

Layer: `water` `waterway` `landcover` `landuse` `park` `boundary` `aeroway`
`transportation` `transportation_name` `building` `water_name` `place`
`housenumber` `poi` `mountain_peak`.

## Rel ADA dalam jubin

Layer `transportation`, medan `class` dan `subclass`. Menyahkod jubin
sebenar atas KL Sentral (z14) mengesahkan nilai ini hadir:

```
class:    rail, transit
subclass: subway, light_rail, monorail
```

Jadi MRT, LRT dan Monorail boleh dibezakan **percuma** dari jubin yang app
sudah muat turun. Menyerlahkannya cuma perlu tambah layer garis sendiri
atas sumber `openmaptiles` sedia ada - tiada rangkaian tambahan.

Layer `poi` bawa stesen berserta nama: `Stasiun MRT Muzium Negara`,
`LRT Bangsar`, `Abdullah Hukum (KTM)`, dengan `subclass` termasuk `subway`
dan `subway_entrance`.

## Tapi identiti laluan TIADA

Ini sebab overlay transit guna GTFS dan bukan menggaya semula jubin.

Skema `transportation_name` **mengisytiharkan** `route_1_colour` sehingga
`route_16_colour`, jadi ia nampak menjanjikan. Memeriksa jubin KL sebenar:

- **sifar** nilai warna dalam keseluruhan jubin, dan
- satu-satunya entri `route_*` ialah koridor pejalan kaki (`MRT Linkway`,
  `KL Sentral - Nu Sentral ... Pedestrian Corridor`), bukan laluan rel.

Jadi pewarnaan ikut **mod** (subway/light_rail/monorail) boleh dari jubin.
"Laluan Kajang hijau, Kelana Jaya merah jambu" **tidak boleh**.

Amaran kedua: pemetaan mod ke jenama bergantung pada ketekalan tag OSM. Di
Lembah Klang ia biasanya betul, tapi ia bukan jaminan per laluan.

## Nama stesen OSM tak konsisten

Data KL sebenar mengandungi kesemua bentuk ini untuk stesen yang sama jenis:

```
Stasiun LRT Bangsar
LRT Bangsar
Abdullah Hukum (LRT)
Abdullah Hukum (KTM)
MRT Pusat Bandar Damansara Pintu A
```

Ada juga skrip bukan-Latin (Tamil, Jepun) sebagai nilai nama berasingan.
Kalau anda pernah melabel stesen dari layer `poi`, ia perlu dinormalkan
dahulu - kalau tidak label nampak bercampur-baur.

Ini satu lagi sebab GTFS lebih baik untuk stesen: `stops.txt` bersih dan
konsisten.

## Cara memeriksa jubin sendiri

Jubin ialah protobuf ter-gzip. Tanpa pustaka MVT, imbasan rentetan sudah
cukup untuk menjawab "adakah nilai ini wujud":

```bash
# kira x/y untuk lat/lon pada zum tertentu, kemudian:
curl -s --compressed \
  "https://tiles.openfreemap.org/planet/<versi>/14/12819/8049.pbf" -o kl.pbf
python3 -c "
import gzip,re
d=open('kl.pbf','rb').read()
if d[:2]==b'\x1f\x8b': d=gzip.decompress(d)
print(sorted({t.decode() for t in re.findall(rb'[a-z_]{3,20}', d)})[:80])"
```

Untuk membaca kunci/nilai setiap layer dengan betul, penghurai protobuf
varint minimum (~30 baris Python) memadai - Tile ialah `repeated Layer`
(medan 3); Layer ada `name` (1), `keys` (3), `values` (4).

## Atribusi

Wajib, bukan pilihan. Dasar jubin OSM juga memblok User-Agent generik -
lihat `kMapUserAgentPackageName` dalam `map_tile_source.dart`; string
`com.example.app` akan dapat jubin kosong.
