# Data Pengangkutan Awam

Dari mana data laluan/stesen Rapid KL datang, cara mengambilnya semula, dan
apa yang feed itu **tidak** ada.

## Sumber: GTFS statik data.gov.my

Kerajaan Malaysia terbitkan GTFS statik melalui satu API terbuka. Tiada
kunci API, tiada pendaftaran.

```
https://api.data.gov.my/gtfs-static/<agensi>[?category=<kategori>]
```

Endpoint yang disahkan wujud (diuji 2026-09-04):

| Agensi/kategori                        | Saiz zip | Guna? |
|----------------------------------------|----------|-------|
| `prasarana?category=rapid-rail-kl`     | 80 KB    | **Ya** |
| `prasarana?category=rapid-bus-kl`      | 1.7 MB   | Tidak |
| `prasarana?category=rapid-bus-mrtfeeder` | 2.0 MB | Tidak |
| `prasarana?category=rapid-bus-penang`  | 4.5 MB   | Tidak |
| `ktmb`                                 | 47 KB    | Tidak - lihat had di bawah |

`rapid-rail-penang` dan `rapid-bus-kuantan` pulangkan 404 - ia tak wujud,
jangan bazir masa mencarinya.

Ambil dan intai:

```bash
curl -sL "https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl" -o rail.zip
unzip -o rail.zip -d rail && cat rail/routes.txt
```

## Apa yang ada dalam feed rapid-rail-kl

`agency.txt` `calendar.txt` `frequencies.txt` `routes.txt` `shapes.txt`
`stop_times.txt` `stops.txt` `trips.txt`

Lapan laluan, dengan warna **rasmi**:

| route_id | category | Laluan                | Warna     | Titik bentuk |
|----------|----------|-----------------------|-----------|--------------|
| `AG`     | LRT      | LRT Ampang Line       | `#e57200` | 210 |
| `KJ`     | LRT      | LRT Kelana Jaya Line  | `#D50032` | 682 |
| `PH`     | LRT      | LRT Sri Petaling Line | `#76232f` | 590 |
| `KGL`    | MRT      | MRT Kajang Line       | `#047940` | 580 |
| `PYL`    | MRT      | MRT Putrajaya Line    | `#FFCD00` | 714 |
| `MR`     | MRL      | KL Monorail Line      | `#84bd00` | 192 |
| `SA`     | LRT      | LRT Shah Alam Line    | `#00A9E0` | 549 |
| `BRT`    | BRT      | BRT Sunway Line       | `#115740` | 123 |

`BRT` **dibuang** oleh saluran penyulaan: ia perkhidmatan bas, bukan rel.
Tinggal tujuh laluan rel.

`stops.txt` ada 187 baris dengan `stop_name`, `stop_lat`, `stop_lon`,
`category`, `route_id`, dan `isOKU` (akses OKU). 151 daripadanya milik tujuh
laluan rel; selebihnya BRT.

## Tiga perangkap dalam feed ini

Ketiga-tiganya sudah dikendalikan oleh `tool/build_transit_assets.dart`.
Ia disenarai di sini supaya sesiapa yang menulis semula saluran itu tak
jumpa semula dengan cara yang susah.

**1. Setiap laluan ada DUA bentuk.** `shapes.txt` simpan `shp_AG_0` dan
`shp_AG_1` - arah 0 dan 1. Melukis kedua-dua bermakna setiap laluan
dilukis dua kali bertindih. Ambil arah 0 sahaja.

**2. Lajur `geometry` dalam `stops.txt` rosak.** Setiap nilai literal
berbunyi `[object Object]` - pepijat dalam eksport mereka. Abaikan lajur
itu sepenuhnya; guna `stop_lat`/`stop_lon`.

**3. Stesen pertukaran berulang, satu baris setiap laluan.** 151 baris rel
menjadi hanya **132 stesen unik**. Masjid Jamek muncul tiga kali (AG, KJ, PH),
Titiwangsa empat kali (AG, PH, PYL, MR). Koordinatnya hampir sama tapi
tidak serupa - dua baris Maluri terpisah kira-kira 40 m.

Tanpa gabungan, pertukaran jadi timbunan bulatan bertindih dan tap
memulangkan satu laluan rawak. Saluran itu gabung ikut nama huruf besar,
kumpul semua `route_id`, dan letak stesen pada sentroid.

Gabungan ikut nama hanya selamat selagi nama unik setiap stesen, jadi
skrip **gagal dengan kuat** bila kelompok tergabung merentangi lebih 300 m.
Kelompok paling teruk dalam feed semasa menyimpang 147 m dari sentroidnya,
jadi ambang itu ada kira-kira 2x ruang lega - ia pengawal, bukan formaliti.
Gabungan senyap dua stesen berlainan yang berkongsi nama akan meletakkan
stesen di tempat salah, dan itu lebih teruk daripada bina yang gagal.

## Had: KTM Komuter tiada

Orang Lembah Klang kira KTM Komuter sebahagian rangkaian, dan ia tak ada
di sini.

Feed KTMB (`https://api.data.gov.my/gtfs-static/ktmb`) ada `routes.txt`
dengan warna rasmi - Seremban Line `#3C5A9F`, Port Klang Line `#DC2420` -
dan `stops.txt`. Tetapi ia **tiada `shapes.txt` langsung**. Tiada geometri
laluan untuk dilukis.

Menyambung stesennya ikut turutan `stop_times` akan hasilkan garis lurus
memotong bandar: bukan sahaja salah, tapi nampak salah.

Pilihan untuk pusingan kemudian, ikut susunan kos:

1. **Stesen KTM sahaja, tiada garisan.** Murah dan jujur - titik muncul,
   laluan tidak.
2. **Ambil geometri dari OSM.** Relation `route=train` dengan
   `network=KTM Komuter` melalui Overpass. Tepat, tapi menambah kebergantungan
   pada Overpass dan ketekalan tag OSM.
3. **Surih tangan sekali.** Geometri Komuter jarang berubah. Ia kerja
   sekali, dan hasilnya jadi aset macam yang lain.

## Jana semula aset

Jalankan bila laluan baru dibuka (contoh: LRT3 penuh, sambungan MRT):

```bash
dart run tool/build_transit_assets.dart
```

Ia muat turun feed, sula, dan tulis semula:

- `assets/transit/rail_lines.geojson` (71 KB, 7 LineString)
- `assets/transit/rail_stations.geojson` (20 KB, 132 stesen tergabung)

Kira-kira 22 KB bila gzip. Warna ditulis ke dalam setiap ciri, jadi
penggayaan dipacu data (`["get", "color"]`) dan masa jalan tak perlu
jadual carian.

Guna `--zip <path>` untuk baca fail tempatan dan bukan memuat turun -
berguna bila menguji perubahan saluran tanpa memukul API berulang kali.

**Aset itu di-commit ke repo.** Ia data, bukan hasil bina yang boleh
diterbitkan semula secara automatik: kalau data.gov.my terbitkan feed rosak,
kita mahu ia gagal masa `dart run`, bukan masa CI.

## Kenapa bundle dan bukan ambil masa jalan

Data ini berubah bila laluan baru dibuka - beberapa kali sedekad, bukan
mingguan. Aset yang dibundel tiada laluan offline, tiada timeout, tiada
laluan zip rosak, dan tiada penghurai GTFS pada peranti. Pengambilan masa
jalan akan menambah keempat-empat mod gagal itu untuk kesegaran yang
hampir tak pernah penting.

## BELUM SELESAI: lesen

Terma data.gov.my untuk **mengedar semula** data mereka di dalam APK yang
dihantar **belum disahkan**. Halaman terma mereka dirender JavaScript dan
tak dapat dibaca secara program.

Kod ini beranggapan atribusi memadai. **Sahkan terma sebelum keluaran.**
Kalau edaran semula tak dibenarkan, pilihan sandaran ialah ambil masa jalan
dengan cache - data sama, tapi tak dibundel.
