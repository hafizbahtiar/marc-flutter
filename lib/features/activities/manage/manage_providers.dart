/// Provider & repository untuk skrin PENGURUSAN modul aktiviti.
///
/// Diletakkan dalam fail sendiri, bukan ditambah ke `activity_providers
/// .dart`: semua yang di sini memerlukan role pengurusan, dan senarai
/// pendaftaran membawa nama sebenar dan `member_id` ahli lain. Sempadan
/// fail menjadikan "siapa boleh sentuh data ini" boleh dibaca dalam senarai
/// import — halaman ahli biasa tidak pernah mengimport fail ini.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/activities/activity_models.dart';
import 'package:marc/features/activities/activity_providers.dart';
import 'package:marc/features/activities/manage/activity_draft.dart';
import 'package:marc/features/activities/manage/scan_result.dart';
import 'package:marc/features/profile/profile_providers.dart';

/// Semakan role untuk MENYEMBUNYIKAN pintu, bukan untuk menguncinya.
/// Backend menyemak `authz.IsManagement` sendiri pada setiap route ini.
final isManagementProvider = Provider<bool>((ref) {
  final profile = ref.watch(myProfileProvider);
  return profile.valueOrNull?.isManagement ?? false;
});

/// Siling "manager ke atas sahaja" — lebih ketat drpd [isManagementProvider]
/// (yang termasuk supervisor). Dikira secara DINAMIK drpd `rolesProvider`
/// (bukan nombor rank digodam keras di klien) supaya siling ini terus betul
/// kalau rank role diubah di backend suatu hari nanti. Sama macam provider
/// di atas — kemudahan UI sahaja, backend menyemak `authz.IsAtLeastRole`
/// sendiri (lihat CRUD kategori aktiviti).
final isManagerOrAboveProvider = Provider<bool>((ref) {
  final profile = ref.watch(myProfileProvider).valueOrNull;
  if (profile == null) return false;

  final roles = ref.watch(rolesProvider).valueOrNull;
  if (roles == null) return false;

  int? managerRank;
  for (final r in roles) {
    if (r.key == 'manager') {
      managerRank = r.rank;
      break;
    }
  }
  if (managerRank == null) return false;

  return profile.roleRank >= managerRank;
});

/// SEMUA kategori aktiviti (termasuk tidak aktif) — utk skrin CRUD
/// pengurusan. `activityCategoriesProvider` (activity_providers.dart) kekal
/// aktif-sahaja utk borang cipta aktiviti; provider ini sengaja fail senyap
/// (list kosong) kalau bukan manager ke atas, elak panggilan 403 yang
/// pengguna tak boleh buat apa-apa dengannya.
final allActivityCategoriesProvider = FutureProvider<List<ActivityCategory>>((
  ref,
) async {
  if (!ref.watch(isManagerOrAboveProvider)) return const [];

  final res = await ref
      .watch(dioProvider)
      .get('/activity-categories', queryParameters: {'all': 'true'});
  final data = res.data as Map<String, dynamic>;
  return (data['categories'] as List)
      .map((c) => ActivityCategory.fromJson(c as Map<String, dynamic>))
      .toList();
});

/// Satu baris `GET /activities/:id/registrations`.
///
/// Medan mengikut `ListRegistrationsByActivityRow` dalam
/// `internal/db/sqlc/activity_registrations.sql.go`. Baris yang dibatalkan
/// TIDAK dipulangkan oleh query itu, jadi tiada penapisan di sini.
///
/// `checkin_token` ada dalam respons tetapi SENGAJA tidak dimodelkan: skrin
/// pengurusan menanda kehadiran dengan `registration_id`, jadi token ahli
/// lain tiada sebab untuk hidup dalam memori app ini.
class ActivityRegistrant {
  const ActivityRegistrant({
    required this.id,
    required this.userId,
    required this.status,
    required this.memberId,
    required this.displayName,
    required this.registeredAt,
    required this.attendedSessionIds,
  });

  /// id PENDAFTARAN — inilah `registration_id` yang dihantar semasa
  /// menanda kehadiran, bukan `user_id`.
  final String id;
  final String userId;
  final String status;
  final String memberId;

  /// Boleh kosong: profil tanpa nama paparan wujud.
  final String displayName;
  final DateTime registeredAt;

  /// Id SESI yang pendaftaran ini sudah ditanda hadir — disusun ikut `seq`,
  /// dan hanya sesi milik aktiviti yang sama.
  ///
  /// Ini yang membenarkan skrin kehadiran menyemai suisnya daripada SATU
  /// permintaan dan bukan meneka. Backend menjaminnya sentiasa hadir dan
  /// sentiasa array (`[]` bila tiada), jadi tiada laluan null di sini —
  /// tetapi lalai kosong dikekalkan supaya klien lama tidak pecah kalau
  /// medan itu hilang.
  final List<String> attendedSessionIds;

  String get name => displayName.isNotEmpty ? displayName : memberId;

  bool attended(String sessionId) => attendedSessionIds.contains(sessionId);

  factory ActivityRegistrant.fromJson(Map<String, dynamic> json) =>
      ActivityRegistrant(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        status: (json['status'] as String?) ?? '',
        memberId: (json['member_id'] as String?) ?? '',
        displayName: (json['display_name'] as String?) ?? '',
        registeredAt: DateTime.parse(json['registered_at'] as String).toLocal(),
        attendedSessionIds:
            (json['attended_session_ids'] as List<dynamic>?)
                ?.cast<String>()
                .toList() ??
            const [],
      );
}

/// Senarai peserta bagi satu aktiviti. Disusun ikut nama supaya pengurus
/// boleh mencari orang di hadapannya tanpa menatal keseluruhan senarai.
final activityRegistrantsProvider =
    FutureProvider.family<List<ActivityRegistrant>, String>((
      ref,
      activityId,
    ) async {
      final isLoggedIn = ref.watch(
        authNotifierProvider.select((s) => s.isLoggedIn),
      );
      if (!isLoggedIn) return const [];

      final res = await ref
          .watch(dioProvider)
          .get('/activities/$activityId/registrations');
      final data = res.data as Map<String, dynamic>;
      final rows = (data['registrations'] as List)
          .map((r) => ActivityRegistrant.fromJson(r as Map<String, dynamic>))
          .toList();
      rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return rows;
    });

// ---- Hasil operasi ----

/// Mutasi yang memulangkan aktiviti (cipta/kemas kini/terbit/batal).
class ActivityResult {
  const ActivityResult.ok(Activity this.activity) : message = null;
  const ActivityResult.failed(String this.message) : activity = null;

  final Activity? activity;
  final String? message;

  bool get isOk => message == null;
}

/// Mutasi tanpa nilai pulangan (ganti sesi, buang kehadiran).
class OpResult {
  const OpResult.ok() : message = null;
  const OpResult.failed(String this.message);

  final String? message;

  bool get isOk => message == null;
}

/// 409 daripada `PUT /activities/:id/sessions`.
///
/// Backend menolak penggantian set sesi sebaik SEBARANG kehadiran direkod
/// untuk aktiviti itu — bukan hanya bagi sesi yang dibuang, kerana
/// `activity_attendances.session_id` ialah `on delete cascade` dan padam
/// itu akan memusnahkan bukti sijil secara senyap. Mesej generik "gagal
/// simpan" di sini akan menyuruh pengurus mencuba lagi selama-lamanya.
const sessionsAttendanceConflictMessage =
    'Sesi tidak boleh diganti kerana kehadiran sudah direkod untuk aktiviti '
    'ini. Kehadiran yang sudah ditanda ialah bukti sijil — buang kehadiran '
    'berkenaan dahulu sebelum menukar sesi.';

/// 422 daripada `POST .../attendance` tanpa `amend`.
const attendanceOutsideWindowMessage =
    'Di luar tetingkap check-in (2 jam sebelum hingga 2 jam selepas sesi).';

/// 202 daripada `POST /activities/:id/certificates`.
///
/// Baris sijil SUDAH dicipta dan komit; hanya sebahagian PDF belum siap
/// dimuat naik. Melaporkannya sebagai ralat akan menyebabkan pengurus
/// menganggap tiada apa berlaku, sedangkan panggilan kedua akan menyambung
/// dari tempat ia berhenti.
const certificatesPartialMessage =
    'Sijil sudah dicipta, tetapi sebahagian failnya belum siap dimuat naik. '
    'Tekan Terbitkan sekali lagi untuk menyambung.';

/// Tempoh menunggu bagi `POST /activities/:id/certificates` SAHAJA.
///
/// Lalai global 12 saat tidak sesuai di sini: fasa 2 server menjana dan
/// memuat naik setiap PDF secara berjujukan (diukur ~0.7s sesijil, had 30s
/// bagi satu muat naik). Dengan lalai itu, mana-mana kohort melebihi ~15
/// sijil akan dibatalkan dio pada 12 saat — gin membatalkan konteks
/// request, gelung muat naik mati separuh jalan, dan pengurus tidak pernah
/// nampak kad 202 walaupun untuk saiz aktiviti yang paling memerlukannya.
///
/// Hanya panggilan ini yang dilanjutkan; lalai global kekal 12 saat.
const certificatesIssueTimeout = Duration(minutes: 5);

/// Dio berhenti menunggu sebelum server sempat menjawab.
///
/// Bukan kegagalan: fasa 1 komit SEBELUM PDF pertama dijana, jadi baris
/// sijil sudah wujud dan server masih menyambung muat naik. Kiraan sebenar
/// tidak diketahui di sini, jadi ia tidak dipapar.
const certificatesTimeoutMessage =
    'Penerbitan mengambil masa lebih lama daripada jangkaan. Sijil sudah '
    'dicipta dan failnya masih dimuat naik di server. Tekan Terbitkan '
    'sekali lagi untuk menyemak dan menyambung.';

/// Hasil satu percubaan menanda kehadiran.
class AttendanceResult {
  const AttendanceResult._({
    required this.ok,
    required this.outsideWindow,
    this.created = false,
    this.message,
  });

  /// [created] false = ahli itu SUDAH ditanda hadir sebelum ini. Bukan
  /// ralat: backend `on conflict do nothing`, dan pengurus yang menekan
  /// dua kali patut nampak hijau, bukan merah.
  const AttendanceResult.ok({required bool created})
    : this._(ok: true, outsideWindow: false, created: created);

  /// 422 — perlu laluan pindaan (`amend` + `reason`).
  const AttendanceResult.outsideWindow()
    : this._(
        ok: false,
        outsideWindow: true,
        message: attendanceOutsideWindowMessage,
      );

  const AttendanceResult.failed(String message)
    : this._(ok: false, outsideWindow: false, message: message);

  final bool ok;
  final bool outsideWindow;
  final bool created;
  final String? message;
}

/// Hasil `POST /activities/:id/certificates`.
class IssueCertificatesResult {
  const IssueCertificatesResult._({
    required this.ok,
    required this.partial,
    required this.issued,
    required this.filesReady,
    this.countsKnown = true,
    this.message,
  });

  /// 200 — semua fail siap.
  const IssueCertificatesResult.done({
    required int issued,
    required int filesReady,
  }) : this._(ok: true, partial: false, issued: issued, filesReady: filesReady);

  /// 202 — baris dicipta, sebahagian fail belum siap. BERJAYA, bukan ralat.
  const IssueCertificatesResult.partial({
    required int issued,
    required int filesReady,
  }) : this._(
         ok: true,
         partial: true,
         issued: issued,
         filesReady: filesReady,
         message: certificatesPartialMessage,
       );

  /// Dio tamat masa menunggu — server masih bekerja. Dilayan seperti 202
  /// (berjaya separuh jalan), cuma tanpa kiraan: tiada respons dibaca, jadi
  /// memapar 0/0 akan menipu.
  const IssueCertificatesResult.timedOut()
    : this._(
        ok: true,
        partial: true,
        issued: 0,
        filesReady: 0,
        countsKnown: false,
        message: certificatesTimeoutMessage,
      );

  const IssueCertificatesResult.failed(String message)
    : this._(
        ok: false,
        partial: false,
        issued: 0,
        filesReady: 0,
        message: message,
      );

  final bool ok;
  final bool partial;

  /// `false` bila panggilan tamat masa: [issued] dan [filesReady] tidak
  /// dibaca daripada server dan tidak boleh dipapar.
  final bool countsKnown;

  /// Berapa baris sijil BARU dicipta panggilan ini.
  final int issued;

  /// Berapa sijil aktiviti ini yang failnya sudah ada — SELURUH aktiviti,
  /// bukan delta panggilan semasa (lihat `countFilesReady` di backend).
  final int filesReady;
  final String? message;
}

/// Mutasi yang memulangkan kategori aktiviti (cipta/kemas kini).
class CategoryResult {
  const CategoryResult.ok(ActivityCategory this.category) : message = null;
  const CategoryResult.failed(String this.message) : category = null;

  final ActivityCategory? category;
  final String? message;

  bool get isOk => message == null;
}

final activityManageRepositoryProvider = Provider<ActivityManageRepository>(
  (ref) => ActivityManageRepository(ref),
);

class ActivityManageRepository {
  ActivityManageRepository(this._ref);
  final Ref _ref;

  Dio get _dio => _ref.read(dioProvider);

  /// Selepas mana-mana mutasi aktiviti: senarai dan detail dibaca semula
  /// dari server, bukan ditampal daripada teka-teki tempatan.
  void _invalidate(String activityId) {
    _ref.invalidate(activityDetailProvider(activityId));
    _ref.read(activitiesProvider.notifier).refresh();
  }

  /// Selepas kehadiran ditanda atau dibuang.
  ///
  /// `activityRegistrantsProvider` ialah `FutureProvider.family` biasa —
  /// keep-alive seumur hayat `ProviderContainer`, mengikut konvensyen repo
  /// ini (tiada satu pun provider `autoDispose` dalam `lib/`). Tanpa
  /// pembatalan di sini, cache itu HIDUP LEBIH LAMA daripada skrin: pengurus
  /// menanda 30 orang, tekan kembali, buka semula — `State` baharu bermula
  /// dengan tindihan kosong dan provider memainkan semula respons SEBELUM
  /// tanda, jadi 30 suis dipapar OFF untuk orang yang hadir.
  ///
  /// Itu lebih buruk daripada keadaan asal: dahulu sepanduk mengakui skrin
  /// tidak tahu; sekarang ia membentangkan data basi sebagai kebenaran
  /// server.
  ///
  /// Kosnya ialah satu bacaan senarai bagi setiap tanda. Diterima dengan
  /// sedar: menanda ialah tindakan berkelajuan manusia (bukan letusan), dan
  /// tindihan tempatan menahan suis pada nilai betul sementara bacaan itu
  /// mendarat, jadi tiada kelipan. `.autoDispose` akan lebih murah (satu
  /// bacaan setiap kemasukan skrin) tetapi tiada preseden langsung dalam
  /// repo ini.
  void _invalidateRegistrants(String activityId) {
    _ref.invalidate(activityRegistrantsProvider(activityId));
  }

  /// `POST /activities` — status kekal `draft` sehingga diterbitkan.
  Future<ActivityResult> create(
    ActivityDraft draft,
    List<SessionDraft> sessions,
  ) async {
    try {
      final res = await _dio.post(
        '/activities',
        data: buildCreateBody(draft, sessions),
      );
      _ref.read(activitiesProvider.notifier).refresh();
      return ActivityResult.ok(
        Activity.fromJson(res.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return ActivityResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const ActivityResult.failed('Gagal cipta aktiviti.');
    }
  }

  /// `PATCH /activities/:id` — [patch] mesti sudah menjadi diff (lihat
  /// `buildActivityPatch`). Repository tidak membinanya sendiri supaya
  /// tiada laluan yang boleh menghantar objek penuh "buat sementara".
  Future<ActivityResult> update(
    String activityId,
    Map<String, dynamic> patch,
  ) async {
    try {
      final res = await _dio.patch('/activities/$activityId', data: patch);
      _invalidate(activityId);
      return ActivityResult.ok(
        Activity.fromJson(res.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return ActivityResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const ActivityResult.failed('Gagal kemas kini aktiviti.');
    }
  }

  /// `PUT /activities/:id/sessions` — set PENUH.
  Future<OpResult> replaceSessions(
    String activityId,
    List<SessionDraft> sessions,
  ) async {
    try {
      await _dio.put(
        '/activities/$activityId/sessions',
        data: buildSessionsBody(sessions),
      );
      _invalidate(activityId);
      return const OpResult.ok();
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        return const OpResult.failed(sessionsAttendanceConflictMessage);
      }
      return OpResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const OpResult.failed('Gagal kemas kini sesi.');
    }
  }

  Future<ActivityResult> publish(String activityId) =>
      _statusChange('/activities/$activityId/publish', activityId, null);

  /// `POST /activities/:id/cancel` — sebab WAJIB, dan ia sampai kepada
  /// setiap ahli berdaftar melalui notifikasi.
  Future<ActivityResult> cancel(String activityId, String reason) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      return Future.value(
        const ActivityResult.failed('Sebab pembatalan diperlukan.'),
      );
    }
    return _statusChange('/activities/$activityId/cancel', activityId, {
      'reason': trimmed,
    });
  }

  Future<ActivityResult> _statusChange(
    String path,
    String activityId,
    Map<String, dynamic>? body,
  ) async {
    try {
      final res = await _dio.post(path, data: body);
      _invalidate(activityId);
      return ActivityResult.ok(
        Activity.fromJson(res.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return ActivityResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const ActivityResult.failed('Gagal kemas kini status aktiviti.');
    }
  }

  /// SATU-SATUNYA tempat yang menghantar `POST .../attendance`.
  ///
  /// Dua skrin memanggilnya: senarai peserta ([markAttendance], dengan
  /// `registration_id` + `method:'manual'`) dan pengimbas QR
  /// ([checkInByToken], dengan `checkin_token` + `method:'scan'`). Handler
  /// backend, baris pangkalan data dan jejak audit adalah SAMA — hanya
  /// bentuk pengenalan berbeza — jadi menyalin permintaan ini ke dalam
  /// skrin scanner bermakna dua tempat untuk pembatalan cache dan dua
  /// tempat untuk terlupa `_invalidateRegistrants`.
  ///
  /// [identity] mesti mengandungi TEPAT satu pengenalan; backend menolak
  /// 400 kalau kedua-duanya (atau tiada) dihantar.
  ///
  /// Membaling `DioException` mentah dengan sengaja: kedua-dua pemanggil
  /// memetakan ralat kepada jenis hasil BERBEZA (`AttendanceResult` vs
  /// `ScanResult` yang mempunyai enam keadaan), jadi pemetaan tidak boleh
  /// dipusatkan tanpa memaksa satu daripadanya menyahbina yang lain.
  Future<Map<String, dynamic>> _postAttendance({
    required String activityId,
    required String sessionId,
    required Map<String, dynamic> identity,
    String? amendReason,
  }) async {
    final res = await _dio.post(
      '/activities/$activityId/sessions/$sessionId/attendance',
      data: {
        ...identity,
        if (amendReason != null) ...{'amend': true, 'reason': amendReason},
      },
    );
    _invalidateRegistrants(activityId);
    final data = res.data;
    return data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
  }

  /// `POST /activities/:id/sessions/:sid/attendance` daripada pengimbas QR.
  ///
  /// [token] ialah `checkin_token` yang dibaca terus daripada QR ahli. Ia
  /// TIDAK PERNAH dilog dan tidak disimpan di mana-mana selain peta
  /// nyahlantun dalam skrin: sesiapa yang memilikinya boleh ditanda hadir
  /// sebagai ahli itu, dan kehadiran menentukan kelayakan sijil.
  ///
  /// Tiada baris gilir luar talian: check-in memerlukan rangkaian dengan
  /// sengaja. Gilir pada peranti boleh dimanipulasi dengan menukar jam
  /// telefon, dan tetingkap check-in dikuatkuasakan oleh jam SERVER.
  Future<ScanResult> checkInByToken({
    required String activityId,
    required String sessionId,
    required String token,
  }) async {
    try {
      final data = await _postAttendance(
        activityId: activityId,
        sessionId: sessionId,
        identity: {'checkin_token': token, 'method': 'scan'},
      );
      return ScanResult.fromResponse(data);
    } on DioException catch (e) {
      return ScanResult.fromError(e);
    } catch (_) {
      return const ScanResult(
        ScanResultKind.network,
        'Gagal tanda kehadiran. Cuba lagi atau tanda manual.',
      );
    }
  }

  /// `POST /activities/:id/sessions/:sid/attendance`.
  ///
  /// [amendReason] bukan null = pindaan di luar tetingkap check-in. Sebab
  /// KOSONG ditolak di sini dan tidak pernah dihantar: backend menolaknya
  /// 400, dan pindaan tanpa sebab ialah tepat perkara yang jejak audit
  /// wujud untuk menghalang.
  Future<AttendanceResult> markAttendance({
    required String activityId,
    required String sessionId,
    required String registrationId,
    String? amendReason,
  }) async {
    final reason = amendReason?.trim();
    final isAmendment = amendReason != null;
    if (isAmendment && (reason == null || reason.isEmpty)) {
      return const AttendanceResult.failed('Sebab pindaan diperlukan.');
    }

    try {
      final data = await _postAttendance(
        activityId: activityId,
        sessionId: sessionId,
        identity: {'registration_id': registrationId, 'method': 'manual'},
        amendReason: isAmendment ? reason : null,
      );
      final created = data['created'] as bool? ?? true;
      return AttendanceResult.ok(created: created);
    } on DioException catch (e) {
      // 422 hanya bermakna "cuba pindaan" bila kita BELUM mencuba pindaan.
      // Tanpa syarat kedua ini, 422 yang berulang atas sebab lain akan
      // menggelungkan dialog sebab tanpa henti.
      if (e.response?.statusCode == 422 && !isAmendment) {
        return const AttendanceResult.outsideWindow();
      }
      return AttendanceResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const AttendanceResult.failed('Gagal tanda kehadiran.');
    }
  }

  /// `DELETE /activities/:id/sessions/:sid/attendance/:rid`.
  ///
  /// 404 dilayan sebagai BERJAYA: keadaan yang diminta ("orang ini tidak
  /// ditanda hadir") sudah tercapai, dan skrin ini tidak boleh membaca
  /// kehadiran sedia ada daripada server untuk mengetahuinya lebih awal.
  Future<OpResult> unmarkAttendance({
    required String activityId,
    required String sessionId,
    required String registrationId,
  }) async {
    try {
      await _dio.delete(
        '/activities/$activityId/sessions/$sessionId/attendance/$registrationId',
      );
      _invalidateRegistrants(activityId);
      return const OpResult.ok();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Sudah tiada di server — cache tempatan mungkin masih menyimpan
        // baris itu sebagai hadir, jadi ia tetap perlu dibaca semula.
        _invalidateRegistrants(activityId);
        return const OpResult.ok();
      }
      return OpResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const OpResult.failed('Gagal buang kehadiran.');
    }
  }

  /// `POST /activities/:id/certificates`.
  ///
  /// 202 ialah KEJAYAAN separuh jalan, bukan kegagalan — lihat
  /// [certificatesPartialMessage].
  Future<IssueCertificatesResult> issueCertificates(String activityId) async {
    try {
      final res = await _dio.post(
        '/activities/$activityId/certificates',
        options: Options(
          sendTimeout: certificatesIssueTimeout,
          receiveTimeout: certificatesIssueTimeout,
        ),
      );
      final data = res.data is Map
          ? res.data as Map<String, dynamic>
          : const <String, dynamic>{};
      final issued = (data['issued'] as num?)?.toInt() ?? 0;
      final filesReady = (data['files_ready'] as num?)?.toInt() ?? 0;

      _ref.invalidate(activityDetailProvider(activityId));

      return res.statusCode == 202
          ? IssueCertificatesResult.partial(
              issued: issued,
              filesReady: filesReady,
            )
          : IssueCertificatesResult.done(
              issued: issued,
              filesReady: filesReady,
            );
    } on DioException catch (e) {
      // Tamat masa menunggu respons BUKAN kegagalan di sini: fasa 1 sudah
      // komit sebelum satu PDF pun dijana, dan server masih meneruskan
      // muat naik selepas dio menutup sambungan. Melaporkannya sebagai
      // "sambungan perlahan" menyembunyikan hakikat bahawa sijil sudah
      // wujud, dan pengurus tidak diberitahu bahawa menekan Terbitkan
      // sekali lagi akan menyambung.
      if (e.type == DioExceptionType.receiveTimeout) {
        return const IssueCertificatesResult.timedOut();
      }
      return IssueCertificatesResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const IssueCertificatesResult.failed('Gagal terbitkan sijil.');
    }
  }

  void _invalidateCategories() {
    _ref.invalidate(allActivityCategoriesProvider);
    _ref.invalidate(activityCategoriesProvider);
  }

  /// `POST /activity-categories` — manager ke atas sahaja (backend
  /// kuatkuasakan `authz.IsAtLeastRole`).
  Future<CategoryResult> createCategory({
    required String key,
    required String name,
    int sortOrder = 0,
  }) async {
    try {
      final res = await _dio.post(
        '/activity-categories',
        data: {'key': key, 'name': name, 'sort_order': sortOrder},
      );
      _invalidateCategories();
      return CategoryResult.ok(
        ActivityCategory.fromJson(res.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return CategoryResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const CategoryResult.failed('Gagal cipta kategori.');
    }
  }

  /// `PATCH /activity-categories/:id` — hanya medan bukan-null dihantar.
  /// `key` sengaja TIDAK boleh diubah (padanan backend) jadi tiada
  /// parameter untuknya di sini.
  Future<CategoryResult> updateCategory(
    String categoryId, {
    String? name,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      final res = await _dio.patch(
        '/activity-categories/$categoryId',
        data: {'name': ?name, 'sort_order': ?sortOrder, 'is_active': ?isActive},
      );
      _invalidateCategories();
      return CategoryResult.ok(
        ActivityCategory.fromJson(res.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return CategoryResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const CategoryResult.failed('Gagal kemas kini kategori.');
    }
  }
}
