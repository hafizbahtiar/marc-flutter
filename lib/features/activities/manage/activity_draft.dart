/// Draf borang aktiviti - model TULEN (tiada Flutter, tiada dio) yang
/// memegang apa yang pengurus taip, dan yang membina badan permintaan.
///
/// Dipisahkan daripada halaman borang dengan SENGAJA: bahagian yang paling
/// mudah rosak secara senyap dalam modul ini ialah pembinaan badan PATCH,
/// dan ia hanya boleh diuji tanpa peranti kalau ia tidak bersarang dalam
/// `State` sesebuah widget.
library;

import 'package:marc/features/activities/activity_models.dart';

/// Satu sesi dalam editor. Boleh ubah (`mutable`) kerana borang menulis
/// terus ke atasnya; `seq` TIADA di sini - ia diterbitkan daripada
/// kedudukan dalam senarai semasa dihantar, jadi nombor urutan mustahil
/// berulang atau berlubang.
class SessionDraft {
  SessionDraft({this.title = '', required this.startsAt, required this.endsAt});

  String title;
  DateTime startsAt;
  DateTime endsAt;

  factory SessionDraft.fromSession(ActivitySession s) =>
      SessionDraft(title: s.title, startsAt: s.startsAt, endsAt: s.endsAt);

  bool get isValid => endsAt.isAfter(startsAt);

  SessionDraft copy() =>
      SessionDraft(title: title, startsAt: startsAt, endsAt: endsAt);

  /// Sama isi (bukan sama objek) - asas bagi keputusan "perlukah PUT
  /// sesi dihantar langsung".
  bool sameAs(SessionDraft other) =>
      title == other.title &&
      startsAt.isAtSameMomentAs(other.startsAt) &&
      endsAt.isAtSameMomentAs(other.endsAt);

  /// `seq` diberi oleh pemanggil daripada kedudukan senarai (1-asas).
  Map<String, dynamic> toJson(int seq) => {
    'seq': seq,
    'title': title.trim(),
    'starts_at': _iso(startsAt),
    'ends_at': _iso(endsAt),
  };
}

/// Medan aktiviti yang borang ini boleh ubah.
///
/// `feeCents` SENGAJA tiada: borang tidak mendedahkannya, jadi ia tidak
/// pernah masuk ke dalam diff dan tidak boleh ditulis ganti secara tidak
/// sengaja kepada 0.
class ActivityDraft {
  ActivityDraft({
    this.categoryId = '',
    this.title = '',
    this.description = '',
    this.locationName = '',
    this.locationAddress = '',
    this.registrationOpensAt,
    this.registrationClosesAt,
    this.capacity,
    this.attendanceThresholdPct = 100,
  });

  String categoryId;
  String title;
  String description;
  String locationName;
  String locationAddress;

  /// null = tiada tarikh buka eksplisit (lajur nullable).
  DateTime? registrationOpensAt;

  /// null hanya semasa mencipta sebelum pengurus memilih tarikh - WAJIB
  /// sebelum hantar.
  DateTime? registrationClosesAt;

  /// null = tiada had kapasiti (lajur nullable).
  int? capacity;

  int attendanceThresholdPct;

  factory ActivityDraft.fromActivity(Activity a) => ActivityDraft(
    categoryId: a.categoryId,
    title: a.title,
    description: a.description,
    locationName: a.locationName,
    locationAddress: a.locationAddress,
    registrationOpensAt: a.registrationOpensAt,
    registrationClosesAt: a.registrationClosesAt,
    capacity: a.capacity,
    attendanceThresholdPct: a.attendanceThresholdPct,
  );

  ActivityDraft copy() => ActivityDraft(
    categoryId: categoryId,
    title: title,
    description: description,
    locationName: locationName,
    locationAddress: locationAddress,
    registrationOpensAt: registrationOpensAt,
    registrationClosesAt: registrationClosesAt,
    capacity: capacity,
    attendanceThresholdPct: attendanceThresholdPct,
  );
}

/// Ralat pengesahan pertama, atau null bila draf boleh dihantar.
///
/// Mengulang semakan backend dengan sengaja - bukan untuk menggantikannya
/// (server tetap hakim), tetapi supaya pengurus nampak masalahnya sebelum
/// menunggu perjalanan pergi-balik rangkaian.
String? validateDraft(ActivityDraft draft, List<SessionDraft> sessions) {
  if (draft.categoryId.isEmpty) return 'Pilih kategori aktiviti.';
  if (draft.title.trim().isEmpty) return 'Tajuk aktiviti diperlukan.';
  if (draft.locationName.trim().isEmpty) return 'Nama lokasi diperlukan.';
  if (draft.registrationClosesAt == null) {
    return 'Tarikh tutup pendaftaran diperlukan.';
  }
  final capacity = draft.capacity;
  if (capacity != null && capacity <= 0) {
    return 'Kapasiti mesti lebih daripada sifar. Kosongkan untuk tiada had.';
  }
  if (draft.attendanceThresholdPct < 1 || draft.attendanceThresholdPct > 100) {
    return 'Ambang kehadiran mesti antara 1 dan 100 peratus.';
  }
  if (sessions.isEmpty) return 'Aktiviti perlu sekurang-kurangnya satu sesi.';
  for (var i = 0; i < sessions.length; i++) {
    if (!sessions[i].isValid) {
      return 'Sesi ${i + 1}: masa tamat mesti selepas masa mula.';
    }
  }
  return null;
}

/// Badan `POST /activities` - LENGKAP, termasuk sesi. Cipta bukan gabungan:
/// backend memerlukan sekurang-kurangnya satu sesi dalam badan yang sama.
Map<String, dynamic> buildCreateBody(
  ActivityDraft draft,
  List<SessionDraft> sessions,
) => {
  'category_id': draft.categoryId,
  'title': draft.title.trim(),
  'description': draft.description.trim(),
  'location_name': draft.locationName.trim(),
  'location_address': draft.locationAddress.trim(),
  if (draft.registrationOpensAt != null)
    'registration_opens_at': _iso(draft.registrationOpensAt!),
  'registration_closes_at': _iso(draft.registrationClosesAt!),
  'capacity': draft.capacity,
  'attendance_threshold_pct': draft.attendanceThresholdPct,
  'sessions': buildSessionsList(sessions),
};

/// Badan `PUT /activities/:id/sessions` - set PENUH, sentiasa.
Map<String, dynamic> buildSessionsBody(List<SessionDraft> sessions) => {
  'sessions': buildSessionsList(sessions),
};

/// `seq` diberi mengikut KRONOLOGI, bukan urutan taip.
///
/// Server tidak peduli - ia hanya menuntut `seq` unik - tetapi skrin
/// kehadiran melabel pemilihnya "Sesi ${seq}", jadi sesi yang ditambah
/// selepas yang lain tetapi berlaku lebih awal akan dibaca sebagai "Sesi 3"
/// pada pagi pertama kursus. Disusun di sini supaya jaminan itu dipegang
/// pada wayar dan bukan bergantung pada UI yang mengingatinya.
List<Map<String, dynamic>> buildSessionsList(List<SessionDraft> sessions) {
  final ordered = [...sessions]
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return [for (var i = 0; i < ordered.length; i++) ordered[i].toJson(i + 1)];
}

/// Badan `PATCH /activities/:id` - HANYA medan yang benar-benar berubah.
///
/// Ini bukan pengoptimuman. Backend menggabungkan medan yang hadir sahaja
/// (lihat `optional[T]` dalam activities.go); menghantar semula keseluruhan
/// objek yang dimuatkan tadi akan menulis ganti suntingan pengurus lain
/// yang mendarat antara muatan dan simpan - dengan nilai yang pengurus INI
/// tidak pernah menaipnya.
///
/// Dua lajur nullable membawa makna pada `null` EKSPLISIT: `capacity` null
/// membuang had, `registration_opens_at` null membuang tarikh buka. Jadi
/// kunci itu dimasukkan dengan nilai null bila ia berubah kepada null -
/// bukan ditinggalkan, yang bermakna "jangan sentuh".
Map<String, dynamic> buildActivityPatch(
  ActivityDraft before,
  ActivityDraft after,
) {
  final body = <String, dynamic>{};

  if (after.categoryId != before.categoryId) {
    body['category_id'] = after.categoryId;
  }
  if (after.title.trim() != before.title.trim()) {
    body['title'] = after.title.trim();
  }
  if (after.description.trim() != before.description.trim()) {
    body['description'] = after.description.trim();
  }
  if (after.locationName.trim() != before.locationName.trim()) {
    body['location_name'] = after.locationName.trim();
  }
  if (after.locationAddress.trim() != before.locationAddress.trim()) {
    body['location_address'] = after.locationAddress.trim();
  }
  if (!_sameInstant(before.registrationOpensAt, after.registrationOpensAt)) {
    final opens = after.registrationOpensAt;
    body['registration_opens_at'] = opens == null ? null : _iso(opens);
  }
  if (!_sameInstant(before.registrationClosesAt, after.registrationClosesAt)) {
    // Lajur NOT NULL - null di sini ditolak 400 oleh backend, jadi ia
    // tidak pernah dihantar. validateDraft sudah menghalang draf tanpa
    // tarikh tutup daripada sampai ke sini.
    final closes = after.registrationClosesAt;
    if (closes != null) body['registration_closes_at'] = _iso(closes);
  }
  if (before.capacity != after.capacity) {
    body['capacity'] = after.capacity;
  }
  if (before.attendanceThresholdPct != after.attendanceThresholdPct) {
    body['attendance_threshold_pct'] = after.attendanceThresholdPct;
  }

  return body;
}

/// Perlukah set sesi dihantar semula?
///
/// `PUT` sesi memadam dan memasukkan semula SEMUA baris, dan ia ditolak
/// 409 sebaik ada kehadiran direkod. Menghantarnya bila tiada apa yang
/// berubah bermakna suntingan tajuk yang tidak berkaitan gagal dengan
/// "sesi sudah ada kehadiran" - jadi perbandingan ini yang menentukan
/// sama ada permintaan itu dibuat langsung.
/// Kedua-dua belah disusun ikut masa mula sebelum dibandingkan - susunan
/// yang SAMA yang `buildSessionsList` gunakan untuk memberi `seq`. Tanpa
/// itu, aktiviti lama yang `seq`-nya tidak mengikut kronologi akan
/// kelihatan "berubah" sebaik dibuka, dan borang akan menghantar PUT yang
/// tidak diminta - yang ditolak 409 sebaik ada kehadiran.
bool sessionsChanged(List<SessionDraft> before, List<SessionDraft> after) {
  if (before.length != after.length) return true;

  final a = [...before]..sort((x, y) => x.startsAt.compareTo(y.startsAt));
  final b = [...after]..sort((x, y) => x.startsAt.compareTo(y.startsAt));
  for (var i = 0; i < a.length; i++) {
    if (!a[i].sameAs(b[i])) return true;
  }
  return false;
}

bool _sameInstant(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == null && b == null;
  return a.isAtSameMomentAs(b);
}

/// RFC3339 UTC - bentuk yang `time.Time` Go hurai tanpa teka zon waktu.
String _iso(DateTime dt) => dt.toUtc().toIso8601String();
