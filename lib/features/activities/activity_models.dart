/// Model modul Aktiviti — kelas biasa dengan `fromJson`, ikut corak
/// `post_models.dart`. Repo ini TIDAK guna `freezed`/codegen.
///
/// Semua timestamp ditukar ke waktu tempatan (`toLocal()`) sebaik dihurai:
/// backend hantar RFC3339 dalam UTC, dan setiap paparan dalam app ini
/// waktu tempatan. Menukar sekali di sempadan penghuraian bermakna tiada
/// laluan paparan yang boleh terlupa membuatnya.
library;

class ActivitySession {
  const ActivitySession({
    required this.id,
    required this.seq,
    required this.title,
    required this.startsAt,
    required this.endsAt,
  });

  final String id;
  final int seq;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;

  factory ActivitySession.fromJson(Map<String, dynamic> json) =>
      ActivitySession(
        id: json['id'] as String,
        seq: json['seq'] as int,
        title: (json['title'] as String?) ?? '',
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      );
}

/// Sebab pendaftaran DISEKAT — satu enum, bukan rentetan, supaya model
/// kekal bebas daripada teks paparan dan setiap keadaan boleh diuji tanpa
/// membina widget. Halaman yang memetakannya kepada ayat Bahasa Melayu.
enum RegistrationBlocker {
  /// Aktiviti dibatalkan.
  cancelled,

  /// Aktiviti sudah tamat (`status == 'completed'`).
  completed,

  /// Belum diterbitkan (`draft`) — tiada siapa boleh daftar lagi.
  notPublished,

  /// Diterbitkan, tetapi tetingkap pendaftaran BELUM bermula
  /// (`registration_opens_at` masih di masa depan).
  opensLater,

  /// Tetingkap pendaftaran sudah tertutup.
  closed,

  /// Kapasiti penuh.
  full,
}

class Activity {
  const Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.locationName,
    required this.locationAddress,
    required this.startsAt,
    required this.endsAt,
    required this.registrationClosesAt,
    required this.capacity,
    required this.registrationCount,
    required this.status,
    required this.sessions,
    required this.isRegistered,
    this.registrationOpensAt,
    this.cancelledReason,
    this.attendanceThresholdPct = 100,
    this.certificatesIssuedAt,
    this.feeCents = 0,
  });

  final String id;
  final String title;
  final String description;
  final String categoryId;
  final String categoryName;
  final String locationName;
  final String locationAddress;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime registrationClosesAt;

  /// null = TIADA had kapasiti (lajur nullable di backend). Bukan sifar —
  /// sifar bermakna tiada slot langsung, yang backend memang tolak.
  final int? capacity;
  final int registrationCount;
  final String status;
  final List<ActivitySession> sessions;
  final bool isRegistered;

  /// null = tiada tarikh buka eksplisit; pendaftaran terbuka sebaik
  /// aktiviti diterbitkan. Lajur nullable di backend.
  final DateTime? registrationOpensAt;
  final String? cancelledReason;

  /// Peratus sesi yang mesti dihadiri sebelum seseorang layak menerima
  /// sijil. Lalai backend 100. Hanya skrin pengurusan menggunakannya.
  final int attendanceThresholdPct;

  /// Bila sijil aktiviti ini PERNAH diterbitkan. null = belum pernah.
  /// Bukan jaminan setiap failnya siap — penerbitan berlaku dalam dua
  /// fasa dan boleh disambung.
  final DateTime? certificatesIssuedAt;

  /// Yuran aktiviti dalam sen. 0 = percuma. Pendaftaran aktiviti berbayar
  /// tulis `payment_status='pending'` pada baris pendaftaran — status
  /// bayaran sebenar (belum/dah dibayar) cuma didedahkan oleh
  /// `GET /me/activities` (`MyRegistration.paymentStatus`), BUKAN respons
  /// detail aktiviti ni — jadi medan ni hanya untuk tahu SAMA ADA perlu
  /// bayar (untuk pandu ahli lepas daftar), bukan status bayaran semasa.
  final int feeCents;

  bool get isFull => capacity != null && registrationCount >= capacity!;
  bool get registrationClosed => DateTime.now().isAfter(registrationClosesAt);
  bool get isCancelled => status == 'cancelled';

  /// Baki slot, atau null bila tiada had.
  int? get slotsLeft {
    final cap = capacity;
    if (cap == null) return null;
    final left = cap - registrationCount;
    return left < 0 ? 0 : left;
  }

  /// SATU-SATUNYA gerbang pendaftaran. `canRegister` di bawah diterbitkan
  /// daripadanya, dan halaman detail memetakan enum ini kepada ayat yang
  /// dipapar — jadi butang yang dilumpuhkan dan sebab yang ditulis
  /// MUSTAHIL bercanggah. Dua rantaian selari yang perlu bersetuju akan
  /// menyimpang; ini menghapuskan rantaian kedua itu.
  ///
  /// Urutan mengikut backend (`registerTx`, activity_registrations.go):
  /// status dahulu, kemudian tetingkap masa, kemudian kapasiti. Server
  /// tetap hakim muktamad — ini untuk melumpuhkan butang dan menerangkan
  /// sebabnya, bukan untuk dipercayai.
  RegistrationBlocker? get registrationBlocker {
    if (isCancelled) return RegistrationBlocker.cancelled;
    if (status == 'completed') return RegistrationBlocker.completed;
    if (status != 'published') return RegistrationBlocker.notPublished;

    final opens = registrationOpensAt;
    if (opens != null && DateTime.now().isBefore(opens)) {
      return RegistrationBlocker.opensLater;
    }
    if (registrationClosed) return RegistrationBlocker.closed;
    if (isFull) return RegistrationBlocker.full;
    return null;
  }

  bool get canRegister => !isRegistered && registrationBlocker == null;

  /// Salinan dengan kiraan/status pendaftaran ditindih — untuk kemas kini
  /// optimistik yang perlu digulung semula bila server menolak (409).
  Activity copyWith({int? registrationCount, bool? isRegistered}) => Activity(
    id: id,
    title: title,
    description: description,
    categoryId: categoryId,
    categoryName: categoryName,
    locationName: locationName,
    locationAddress: locationAddress,
    startsAt: startsAt,
    endsAt: endsAt,
    registrationClosesAt: registrationClosesAt,
    capacity: capacity,
    registrationCount: registrationCount ?? this.registrationCount,
    status: status,
    sessions: sessions,
    isRegistered: isRegistered ?? this.isRegistered,
    registrationOpensAt: registrationOpensAt,
    cancelledReason: cancelledReason,
    attendanceThresholdPct: attendanceThresholdPct,
    certificatesIssuedAt: certificatesIssuedAt,
    feeCents: feeCents,
  );

  /// `sessions` dan `is_registered` hanya wujud pada respons DETAIL
  /// (`GET /activities/:id`); baris senarai tidak membawanya. Lalai di
  /// bawah yang menampung perbezaan itu, jadi satu kelas boleh mewakili
  /// kedua-dua bentuk.
  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    id: json['id'] as String,
    title: json['title'] as String,
    description: (json['description'] as String?) ?? '',
    categoryId: (json['category_id'] as String?) ?? '',
    categoryName: (json['category_name'] as String?) ?? '',
    locationName: (json['location_name'] as String?) ?? '',
    locationAddress: (json['location_address'] as String?) ?? '',
    startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
    endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
    registrationClosesAt: DateTime.parse(
      json['registration_closes_at'] as String,
    ).toLocal(),
    registrationOpensAt: json['registration_opens_at'] == null
        ? null
        : DateTime.parse(json['registration_opens_at'] as String).toLocal(),
    capacity: (json['capacity'] as num?)?.toInt(),
    registrationCount: (json['registration_count'] as num?)?.toInt() ?? 0,
    status: json['status'] as String,
    sessions: ((json['sessions'] as List<dynamic>?) ?? const [])
        .map((e) => ActivitySession.fromJson(e as Map<String, dynamic>))
        .toList(),
    isRegistered: (json['is_registered'] as bool?) ?? false,
    cancelledReason: json['cancelled_reason'] as String?,
    attendanceThresholdPct:
        (json['attendance_threshold_pct'] as num?)?.toInt() ?? 100,
    certificatesIssuedAt: json['certificates_issued_at'] == null
        ? null
        : DateTime.parse(json['certificates_issued_at'] as String).toLocal(),
    feeCents: (json['fee_cents'] as num?)?.toInt() ?? 0,
  );
}

class ActivityCategory {
  const ActivityCategory({
    required this.id,
    required this.key,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String key;
  final String name;
  final int sortOrder;

  /// false = disembunyikan drpd borang cipta aktiviti (soft-delete —
  /// `category_id` di `activities` ialah `on delete restrict`, jadi
  /// kategori yang sudah digunakan TIDAK BOLEH dipadam terus).
  final bool isActive;

  factory ActivityCategory.fromJson(Map<String, dynamic> json) =>
      ActivityCategory(
        id: json['id'] as String,
        key: json['key'] as String,
        name: json['name'] as String,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        isActive: (json['is_active'] as bool?) ?? true,
      );
}

/// Satu pendaftaran aktif milik pemanggil — `GET /me/activities`.
///
/// Baris itu meratakan aktiviti berkaitan (title/starts_at/ends_at/
/// activity_status/category_name) ke atas baris pendaftaran, jadi model
/// ini mengikut bentuk rata yang sama dan bukan Activity bersarang.
class MyRegistration {
  const MyRegistration({
    required this.id,
    required this.activityId,
    required this.status,
    required this.checkinToken,
    required this.registeredAt,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.activityStatus,
    required this.categoryName,
    this.paymentStatus = 'not_required',
  });

  final String id;
  final String activityId;
  final String status;

  /// Token QR untuk check-in — legap, dijana crypto/rand di backend.
  final String checkinToken;
  final DateTime registeredAt;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String activityStatus;
  final String categoryName;

  /// Status yuran AKTIVITI (bukan yuran pendaftaran ahli) — lajur
  /// `activity_registrations.payment_status`, satu daripada
  /// `not_required` (percuma), `pending` (belum bayar), `paid`,
  /// `refunded`. Lalai `not_required` untuk keserasian ke belakang kalau
  /// medan tiada dalam respons lama.
  final String paymentStatus;

  bool get isCancelled => activityStatus == 'cancelled';

  /// Yuran aktiviti ini belum dibayar — butang "Bayar Yuran Aktiviti"
  /// patut dipapar.
  bool get feeUnpaid => paymentStatus == 'pending';

  /// Yuran aktiviti ini sudah dibayar.
  bool get feePaid => paymentStatus == 'paid';

  /// Aktiviti ini sudah lepas pada [now].
  ///
  /// `activity_status` diperiksa DAHULU: pengurusan boleh menandakan
  /// aktiviti `completed` sebelum `ends_at` yang dijadualkan, dan sebaik
  /// ia ditanda, check-in ditutup walaupun jam belum sampai.
  bool isDoneAt(DateTime now) =>
      activityStatus == 'completed' || now.isAfter(endsAt);

  /// QR check-in patut dipapar untuk pendaftaran ini.
  ///
  /// Dibatalkan/tamat = tiada gunanya menunjukkan kod yang pengimbas
  /// akan tolak; token kosong (medan tiada dalam respons lama) tidak
  /// boleh dijadikan QR langsung.
  bool canCheckInAt(DateTime now) =>
      !isCancelled && !isDoneAt(now) && checkinToken.isNotEmpty;

  factory MyRegistration.fromJson(Map<String, dynamic> json) => MyRegistration(
    id: json['id'] as String,
    activityId: json['activity_id'] as String,
    status: json['status'] as String,
    checkinToken: (json['checkin_token'] as String?) ?? '',
    registeredAt: DateTime.parse(json['registered_at'] as String).toLocal(),
    title: json['title'] as String,
    startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
    endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
    activityStatus: json['activity_status'] as String,
    categoryName: (json['category_name'] as String?) ?? '',
    paymentStatus: (json['payment_status'] as String?) ?? 'not_required',
  );
}

/// Pendaftaran dipisah kepada "akan datang" dan "lepas".
class RegistrationGroups {
  const RegistrationGroups({required this.upcoming, required this.past});

  final List<MyRegistration> upcoming;
  final List<MyRegistration> past;

  bool get isEmpty => upcoming.isEmpty && past.isEmpty;
}

/// Backend memulangkan SATU senarai disusun `starts_at desc` — susunan
/// yang betul untuk arkib tetapi terbalik untuk apa yang ahli buka skrin
/// ini untuk lihat: aktiviti seterusnya. Yang akan datang disusun semula
/// menaik (paling hampir dahulu) dan yang lepas dibiarkan menurun
/// (paling baru dahulu).
///
/// [now] disuntik supaya sempadan boleh diuji tanpa bergantung pada jam.
RegistrationGroups groupRegistrations(
  List<MyRegistration> rows, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final upcoming = <MyRegistration>[];
  final past = <MyRegistration>[];
  for (final r in rows) {
    (r.isDoneAt(at) ? past : upcoming).add(r);
  }
  upcoming.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  past.sort((a, b) => b.startsAt.compareTo(a.startsAt));
  return RegistrationGroups(upcoming: upcoming, past: past);
}

/// Satu sijil milik pemanggil — `GET /me/certificates`.
///
/// Medan mengikut `certificateResponse` dalam
/// `internal/http/handlers/activity_certificates.go`: tiada `r2_key` di
/// sini, hanya `file_ready`. Sijil yang DITARIK BALIK tidak pernah muncul
/// dalam senarai ini (`ListMyCertificates` menapis `revoked_at is null`).
class MyCertificate {
  const MyCertificate({
    required this.id,
    required this.activityId,
    required this.serial,
    required this.recipientName,
    required this.activityTitle,
    required this.categoryName,
    required this.activityDate,
    required this.issuedAt,
    required this.fileReady,
  });

  final String id;
  final String activityId;
  final String serial;
  final String recipientName;
  final String activityTitle;
  final String categoryName;

  /// Tarikh aktiviti — backend hantar "2026-08-09" TANPA zon waktu, jadi
  /// ia tarikh kalendar dan bukan detik. `toLocal()` sengaja TIDAK
  /// dipanggil: menukar tengah malam tempatan ke zon lain menggelongsor
  /// tarikh sehari, dan tarikh pada sijil bercetak tidak boleh berubah
  /// ikut tempat ahli berdiri.
  final DateTime activityDate;
  final DateTime issuedAt;

  /// PDF sudah dimuat naik. `false` = fasa 2 penerbitan belum selesai;
  /// muat turun akan pulangkan 409 sehingga ia siap.
  final bool fileReady;

  /// `verify_token` SENGAJA tidak dimodelkan. Ia rahsia pengesahan awam
  /// yang dicetak pada PDF; app ini tiada gunanya untuknya, dan medan
  /// yang tidak wujud tidak boleh tersasar ke dalam log.

  factory MyCertificate.fromJson(Map<String, dynamic> json) => MyCertificate(
    id: json['id'] as String,
    activityId: json['activity_id'] as String,
    serial: (json['serial'] as String?) ?? '',
    recipientName: (json['recipient_name'] as String?) ?? '',
    activityTitle: (json['activity_title'] as String?) ?? '',
    categoryName: (json['category_name'] as String?) ?? '',
    activityDate: DateTime.parse(json['activity_date'] as String),
    issuedAt: DateTime.parse(json['issued_at'] as String).toLocal(),
    fileReady: (json['file_ready'] as bool?) ?? false,
  );
}
