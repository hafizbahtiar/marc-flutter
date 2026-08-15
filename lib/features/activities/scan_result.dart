import 'package:dio/dio.dart';

/// Nyahlantun bagi kod QR yang SAMA.
///
/// QR yang dipegang di depan lens mencetuskan pengesanan berpuluh kali
/// sesaat. Tanpa ini, satu peserta menghantar puluhan permintaan POST —
/// satu ditanda, selebihnya `created:false`, dan sepanduk skrin berkelip
/// antara "hadir" dan "sudah ditanda hadir" terlalu pantas untuk dibaca.
///
/// Kod BERBEZA tidak pernah dihalang antara satu sama lain: barisan 40
/// orang bergerak sepantas kamera boleh membaca, dan orang kedua tidak
/// patut menunggu tiga saat kerana orang pertama baru sahaja diimbas.
///
/// Diletakkan di sini dan bukan di dalam `State` skrin supaya ia boleh
/// diuji tanpa kamera. [now] disuntik atas sebab yang sama — ujian tidak
/// boleh menunggu tiga saat sebenar.
class ScanDebouncer {
  ScanDebouncer({this.window = const Duration(seconds: 3)});

  final Duration window;
  final Map<String, DateTime> _recent = {};

  /// true = kod ini baru sahaja diproses; JANGAN hantar permintaan.
  ///
  /// Panggilan yang dibenarkan MENYETEL semula pemasa kod itu; panggilan
  /// yang dihalang tidak. Kalau yang dihalang turut menyetel semula, QR
  /// yang dipegang berterusan tidak akan pernah tamat tempoh dan pengurus
  /// yang benar-benar mahu mengimbas semula orang yang sama tersekat
  /// selama-lamanya.
  bool shouldSkip(String code, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final seen = _recent[code];
    if (seen != null && t.difference(seen) < window) return true;
    _recent[code] = t;
    return false;
  }

  /// Membuang entri yang sudah tamat tempoh.
  ///
  /// Peta ini memegang token check-in ahli lain dalam memori. Ia dibersihkan
  /// setiap imbasan supaya sesi mengimbas 200 orang tidak berakhir dengan
  /// 200 token hidup dalam ingatan proses lebih lama daripada keperluannya.
  void prune({DateTime? now}) {
    final t = now ?? DateTime.now();
    _recent.removeWhere((_, seen) => t.difference(seen) >= window);
  }

  /// Dipanggil semasa skrin dilupuskan — token tidak hidup lebih lama
  /// daripada skrin yang membacanya.
  void clear() => _recent.clear();

  /// Membuang SATU kod daripada penjejakan nyahlantun serta-merta.
  ///
  /// Dipanggil apabila permintaan check-in bagi kod itu GAGAL (mis. wifi
  /// tempat majlis terputus). `shouldSkip` menyetel cap masa semasa
  /// PERMINTAAN dihantar, bukan selepas ia berjaya — tanpa pembuangan ini,
  /// mempersembahkan semula QR yang sama dalam tetingkap nyahlantun akan
  /// disekat diam-diam, dan di pintu itu kelihatan seperti pengimbas beku
  /// walhal kod itu cuma perlu dicuba semula.
  void evict(String code) => _recent.remove(code);

  int get trackedCount => _recent.length;
}

/// Enam keadaan berbeza bagi satu imbasan QR check-in.
///
/// Tanpa pemisahan ini semuanya menjadi "Ralat" dan pengurusan tidak dapat
/// tahu sama ada perlu mengimbas semula, menanda manual, atau memberitahu
/// ahli bahawa dia tidak berdaftar.
///
/// DUA daripadanya bukan kegagalan: [marked] dan [alreadyMarked]. Imbasan
/// berulang ialah kelakuan BIASA di pintu — QR yang sama dipegang semula,
/// dua pengurus mengimbas orang yang sama — dan backend memulangkan 200
/// dengan `created:false` untuknya, bukan ralat.
enum ScanResultKind {
  marked,
  alreadyMarked,
  notRegistered,
  outsideWindow,
  unknownCode,
  network,
}

/// Pemetaan respons/ralat kehadiran kepada satu keadaan yang boleh dipapar.
///
/// Kelas ini SENGAJA berada di luar widget scanner: ia logik pemetaan tulen
/// dan boleh diuji tanpa kamera, tanpa peranti, tanpa `WidgetTester`. Kalau
/// ia hidup dalam `setState` skrin, satu-satunya cara mengesahkan bahawa
/// "sudah hadir" kekal hijau ialah dengan berdiri di pintu dengan telefon.
/// Sepanduk kejayaan di pintu perlu kekal SEBARIS dan boleh dibaca.
///
/// Nama ahli boleh membawa baris baharu terbenam atau panjang sewenang-
/// wenangnya (medan profil tidak dihadkan sisi pelayan) — tanpa ini, satu
/// nama boleh memesongkan seluruh sepanduk atau memaksa teks lain keluar
/// dari skrin. Ini SEMATA-MATA kebersihan paparan, bukan sekatan
/// keselamatan.
String _sanitizeName(String name) {
  final flat = name.replaceAll('\n', ' ');
  return flat.length > 40 ? '${flat.substring(0, 40)}…' : flat;
}

class ScanResult {
  const ScanResult(this.kind, this.message);

  final ScanResultKind kind;
  final String message;

  bool get isFailure =>
      kind != ScanResultKind.marked && kind != ScanResultKind.alreadyMarked;

  /// 200 daripada `POST .../attendance`.
  ///
  /// `created` false bermakna baris kehadiran SUDAH wujud (`on conflict do
  /// nothing` di backend). Itu kejayaan dengan perkataan berbeza, bukan
  /// ralat.
  factory ScanResult.fromResponse(Map<String, dynamic> data) {
    final member = data['member'];
    final rawName = member is Map ? member['display_name'] as String? : null;
    // Profil yang gagal dibaca memulangkan nama kosong (lihat `memberOf`
    // dalam activity_attendance.go) — kehadiran itu tetap SUDAH direkod,
    // jadi skrin mesti mengesahkannya dengan label generik dan bukan
    // kelihatan seperti gagal.
    final nama = _sanitizeName(
      (rawName == null || rawName.isEmpty) ? 'Ahli' : rawName,
    );
    final created = (data['created'] as bool?) ?? false;
    return created
        ? ScanResult(ScanResultKind.marked, '✓ $nama hadir')
        : ScanResult(ScanResultKind.alreadyMarked, '$nama sudah ditanda hadir');
  }

  /// Kod status mengikut `AttendanceHandler.Mark` di backend:
  /// 404 = token tidak dijumpai (atau sesi tiada), 409 = pendaftaran bukan
  /// milik aktiviti ini / dibatalkan, 422 = di luar tetingkap check-in.
  factory ScanResult.fromError(DioException e) {
    if (e.response == null) {
      return const ScanResult(
        ScanResultKind.network,
        'Tiada sambungan. Cuba lagi atau tanda manual.',
      );
    }
    final data = e.response!.data;
    final mesej = (data is Map && data['error'] is String)
        ? data['error'] as String
        : 'Ralat tidak diketahui';
    switch (e.response!.statusCode) {
      case 404:
        // Mesej server dikekalkan: 404 juga dipulangkan untuk "sesi tidak
        // dijumpai", dan memaksa teks "QR tidak dikenali" ke atasnya akan
        // menghantar pengurus memeriksa telefon ahli sedangkan masalahnya
        // sesi yang sudah diganti.
        return ScanResult(
          ScanResultKind.unknownCode,
          data is Map && data['error'] is String ? mesej : 'QR tidak dikenali',
        );
      case 422:
        return ScanResult(ScanResultKind.outsideWindow, mesej);
      case 409:
        return ScanResult(ScanResultKind.notRegistered, mesej);
      default:
        // Baldi merah generik: 400/403/500. Bukan "rangkaian" dari segi
        // teknikal, tetapi ia berkongsi satu-satunya tindakan yang tinggal
        // — cuba lagi atau tanda manual — dan mesej server dibawa apa
        // adanya supaya sebab sebenar tidak hilang.
        return ScanResult(ScanResultKind.network, mesej);
    }
  }
}
