import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/activities/scan_result.dart';

DioException ralat(int status, String mesej) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: {'error': mesej},
  ),
);

void main() {
  test('kehadiran baharu ialah kejayaan', () {
    final r = ScanResult.fromResponse({
      'created': true,
      'member': {'display_name': 'Ahmad'},
    });
    expect(r.kind, ScanResultKind.marked);
    expect(r.message, contains('Ahmad'));
  });

  // Sudah hadir BUKAN ralat. Kalau ia dipaparkan merah, pengurusan akan
  // fikir imbasan gagal dan cuba lagi — atau lebih teruk, tanda manual
  // atas kehadiran yang sudah wujud.
  test('sudah hadir ialah keadaan tersendiri, bukan ralat', () {
    final r = ScanResult.fromResponse({
      'created': false,
      'member': {'display_name': 'Ahmad'},
    });
    expect(r.kind, ScanResultKind.alreadyMarked);
  });

  test('tidak berdaftar dipetakan berasingan', () {
    expect(
      ScanResult.fromError(
        ralat(409, 'ahli ini tidak berdaftar untuk aktiviti ini'),
      ).kind,
      ScanResultKind.notRegistered,
    );
  });

  test('di luar tetingkap dipetakan berasingan', () {
    expect(
      ScanResult.fromError(ralat(422, 'di luar tetingkap check-in')).kind,
      ScanResultKind.outsideWindow,
    );
  });

  test('QR tak dikenali dipetakan berasingan', () {
    expect(
      ScanResult.fromError(ralat(404, 'QR tidak dikenali')).kind,
      ScanResultKind.unknownCode,
    );
  });

  test('kegagalan rangkaian dipetakan berasingan', () {
    final e = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    );
    expect(ScanResult.fromError(e).kind, ScanResultKind.network);
  });

  // ---- Tambahan di luar brief: laluan yang skrin sebenar akan lalui ----

  // Kedua-dua kejayaan mesti HIJAU. `isFailure` ialah satu-satunya tempat
  // warna sepanduk diputuskan, jadi ujian ini yang menahan "sudah hadir"
  // daripada bertukar merah pada refactor kemudian.
  test('kedua-dua keadaan hadir bukan kegagalan', () {
    expect(
      const ScanResult(ScanResultKind.marked, 'x').isFailure,
      isFalse,
    );
    expect(
      const ScanResult(ScanResultKind.alreadyMarked, 'x').isFailure,
      isFalse,
    );
    for (final kind in [
      ScanResultKind.notRegistered,
      ScanResultKind.outsideWindow,
      ScanResultKind.unknownCode,
      ScanResultKind.network,
    ]) {
      expect(ScanResult(kind, 'x').isFailure, isTrue, reason: '$kind');
    }
  });

  // Backend memulangkan display_name kosong bila profil gagal dibaca
  // (lihat `memberOf` dalam activity_attendance.go) — check-in itu SUDAH
  // commit, jadi skrin tidak boleh memaparkan "null hadir".
  test('nama kosong berundur ke label generik', () {
    final r = ScanResult.fromResponse({
      'created': true,
      'member': {'display_name': ''},
    });
    expect(r.kind, ScanResultKind.marked);
    expect(r.message, contains('Ahli'));
  });

  test('respons tanpa member tidak membaling', () {
    final r = ScanResult.fromResponse({'created': true});
    expect(r.kind, ScanResultKind.marked);
  });

  // 500 daripada server bukan masalah rangkaian, tetapi ia juga bukan salah
  // satu daripada empat keadaan bernama — ia jatuh ke baldi merah generik
  // dan MESTI membawa mesej server, bukan "tiada sambungan".
  test('ralat pelayan membawa mesejnya sendiri', () {
    final r = ScanResult.fromError(ralat(500, 'gagal tanda kehadiran'));
    expect(r.isFailure, isTrue);
    expect(r.message, 'gagal tanda kehadiran');
  });

  group('ScanDebouncer', () {
    final t0 = DateTime(2026, 8, 13, 9);

    test('imbasan pertama dibenarkan, imbasan berulang dihalang', () {
      final d = ScanDebouncer();
      expect(d.shouldSkip('tok', now: t0), isFalse);
      expect(
        d.shouldSkip('tok', now: t0.add(const Duration(milliseconds: 40))),
        isTrue,
      );
      expect(
        d.shouldSkip('tok', now: t0.add(const Duration(seconds: 2, milliseconds: 999))),
        isTrue,
      );
    });

    test('dibenarkan semula selepas tetingkap tamat', () {
      final d = ScanDebouncer();
      expect(d.shouldSkip('tok', now: t0), isFalse);
      expect(d.shouldSkip('tok', now: t0.add(const Duration(seconds: 3))), isFalse);
    });

    // Orang kedua dalam barisan tidak menunggu tiga saat kerana orang
    // pertama baru diimbas.
    test('kod berbeza tidak menghalang satu sama lain', () {
      final d = ScanDebouncer();
      expect(d.shouldSkip('a', now: t0), isFalse);
      expect(d.shouldSkip('b', now: t0), isFalse);
    });

    // QR yang dipegang berterusan di depan lens tidak boleh menolak masa
    // tamat ke hadapan selama-lamanya.
    test('imbasan yang dihalang tidak menyetel semula pemasa', () {
      final d = ScanDebouncer();
      d.shouldSkip('tok', now: t0);
      for (var ms = 100; ms < 3000; ms += 100) {
        d.shouldSkip('tok', now: t0.add(Duration(milliseconds: ms)));
      }
      expect(d.shouldSkip('tok', now: t0.add(const Duration(seconds: 3))), isFalse);
    });

    test('prune membuang entri tamat tempoh sahaja', () {
      final d = ScanDebouncer();
      d.shouldSkip('lama', now: t0);
      d.shouldSkip('baharu', now: t0.add(const Duration(seconds: 2)));
      d.prune(now: t0.add(const Duration(seconds: 3)));
      expect(d.trackedCount, 1);
      // 'lama' dibuang, jadi ia dibenarkan semula; 'baharu' masih dijejaki.
      expect(d.shouldSkip('baharu', now: t0.add(const Duration(seconds: 3))), isTrue);
    });

    test('clear membuang semua token yang dijejaki', () {
      final d = ScanDebouncer();
      d.shouldSkip('a', now: t0);
      d.shouldSkip('b', now: t0);
      d.clear();
      expect(d.trackedCount, 0);
    });
  });
}
