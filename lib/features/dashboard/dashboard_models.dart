/// Model skrin Utama (`GET /dashboard`). Penghuraian di sini SENGAJA
/// defensif pada setiap medan: payload dashboard ialah yang paling kerap
/// berubah bentuk antara keluaran, dan app lama di telefon ahli mesti
/// terus berfungsi bila backend menambah atau menyusun semula medan.
/// Kontrak penuh: marc_go docs/superpowers/specs/2026-09-05-dashboard-home-design.md
library;

int _int(Object? v) => switch (v) {
  final int i => i,
  final num n => n.toInt(),
  _ => 0,
};

int? _intOrNull(Object? v) => switch (v) {
  final int i => i,
  final num n => n.toInt(),
  _ => null,
};

double? _doubleOrNull(Object? v) => switch (v) {
  final num n => n.toDouble(),
  _ => null,
};

String _str(Object? v) => v is String ? v : '';

String? _strOrNull(Object? v) => switch (v) {
  final String s when s.trim().isEmpty => null,
  final String s => s,
  _ => null,
};

/// Tarikh tak sah/hilang → epoch, BUKAN lontaran: satu tarikh rosak pada
/// satu kad tidak sepatutnya mengosongkan seluruh skrin Utama.
DateTime _date(Object? v) =>
    DateTime.tryParse(v is String ? v : '') ??
    DateTime.fromMillisecondsSinceEpoch(0);

Map<String, dynamic> _map(Object? v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};

List<Map<String, dynamic>> _list(Object? v) => v is List
    ? v.whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

class Membership {
  const Membership({
    required this.status,
    this.memberId,
    this.staffIdVerified = false,
    this.outstandingFeeCents,
  });

  final String status;
  final String? memberId;
  final bool staffIdVerified;

  /// Null = tiada yuran tertunggak. Backend ialah satu-satunya hakim di
  /// sini - client TIDAK mengira semula kelayakan yuran.
  final int? outstandingFeeCents;

  bool get isApproved => status == 'approved';

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    status: _str(json['status']),
    memberId: _strOrNull(json['member_id']),
    staffIdVerified: json['staff_id_verified'] == true,
    outstandingFeeCents: _intOrNull(json['outstanding_registration_fee_cents']),
  );
}

class OpenActivity {
  const OpenActivity({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.categoryName,
    required this.feeCents,
    required this.currency,
    required this.registrationCount,
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final String categoryName;
  final int feeCents;
  final String currency;
  final int registrationCount;

  factory OpenActivity.fromJson(Map<String, dynamic> json) => OpenActivity(
    id: _str(json['id']),
    title: _str(json['title']),
    startsAt: _date(json['starts_at']),
    categoryName: _str(json['category_name']),
    feeCents: _int(json['fee_cents']),
    currency: _str(json['currency']),
    registrationCount: _int(json['registration_count']),
  );
}

/// Kiraan notifikasi dan senarai "aktiviti saya" tiada di sini: skrin
/// Utama berhenti memaparkan kedua-duanya (notifikasi ialah tab
/// bottom-nav dengan lencananya sendiri; "aktiviti saya" mencerminkan
/// tab Aktiviti dan `/my-activities`), dan backend berhenti menghantar
/// keduanya. Penghuraian di sini tetap defensif, jadi app versi ini
/// tidak akan ranap kalau bertemu backend lama yang masih menghantar
/// medan itu - ia hanya diabaikan.
class MemberBlock {
  const MemberBlock({
    required this.membership,
    required this.openActivities,
    required this.certificatesTotal,
    required this.totalMembers,
  });

  final Membership membership;
  final List<OpenActivity> openActivities;
  final int certificatesTotal;
  final int totalMembers;

  factory MemberBlock.fromJson(Map<String, dynamic> json) => MemberBlock(
    membership: Membership.fromJson(_map(json['membership'])),
    openActivities: _list(
      json['open_activities'],
    ).map(OpenActivity.fromJson).toList(growable: false),
    certificatesTotal: _int(json['certificates_total']),
    totalMembers: _int(json['total_members']),
  );
}

class Revenue {
  const Revenue({
    required this.currency,
    required this.registrationCents,
    required this.activityCents,
    required this.totalCents,
    this.donationCents,
  });

  final String currency;
  final int registrationCents;
  final int activityCents;
  final int totalCents;

  /// Null = pemanggil bukan superadmin, jadi derma DIKECUALIKAN daripada
  /// [totalCents] juga. Kad mesti menyatakan itu, bukan memapar jumlah
  /// yang kelihatan lengkap.
  final int? donationCents;

  bool get includesDonations => donationCents != null;

  factory Revenue.fromJson(Map<String, dynamic> json) => Revenue(
    currency: _str(json['currency']),
    registrationCents: _int(json['registration_cents']),
    activityCents: _int(json['activity_cents']),
    totalCents: _int(json['total_cents']),
    donationCents: _intOrNull(json['donation_cents']),
  );
}

class DepartmentStat {
  const DepartmentStat({
    required this.code,
    required this.name,
    required this.count,
  });

  final String code;
  final String name;
  final int count;

  factory DepartmentStat.fromJson(Map<String, dynamic> json) => DepartmentStat(
    code: _str(json['code']),
    name: _str(json['name']),
    count: _int(json['count']),
  );
}

class MemberStats {
  const MemberStats({
    required this.active,
    required this.pending,
    required this.newThisMonth,
    required this.byDepartment,
  });

  final int active;
  final int pending;
  final int newThisMonth;
  final List<DepartmentStat> byDepartment;

  factory MemberStats.fromJson(Map<String, dynamic> json) => MemberStats(
    active: _int(json['active']),
    pending: _int(json['pending']),
    newThisMonth: _int(json['new_this_month']),
    byDepartment: _list(
      json['by_department'],
    ).map(DepartmentStat.fromJson).toList(growable: false),
  );
}

class ActivityStats {
  const ActivityStats({
    required this.upcoming,
    required this.registrationsThisMonth,
    this.attendanceRate,
  });

  final int upcoming;
  final int registrationsThisMonth;

  /// 0..1, atau null bila pembahagi sifar (tiada sesi tamat bulan ini).
  /// Null BUKAN sama dengan 0 - kad papar "-", bukan "0%".
  final double? attendanceRate;

  factory ActivityStats.fromJson(Map<String, dynamic> json) => ActivityStats(
    upcoming: _int(json['upcoming']),
    registrationsThisMonth: _int(json['registrations_this_month']),
    attendanceRate: _doubleOrNull(json['attendance_rate']),
  );
}

class AdminBlock {
  const AdminBlock({
    required this.pendingApprovals,
    required this.revenue,
    required this.memberStats,
    required this.activityStats,
  });

  final int pendingApprovals;
  final Revenue revenue;
  final MemberStats memberStats;
  final ActivityStats activityStats;

  factory AdminBlock.fromJson(Map<String, dynamic> json) => AdminBlock(
    pendingApprovals: _int(json['pending_approvals']),
    revenue: Revenue.fromJson(_map(json['revenue_this_month'])),
    memberStats: MemberStats.fromJson(_map(json['member_stats'])),
    activityStats: ActivityStats.fromJson(_map(json['activity_stats'])),
  );
}

class DashboardData {
  const DashboardData({required this.member, this.admin});

  final MemberBlock member;

  /// Null = pemanggil bukan admin. Client TIDAK menentukan kelayakan
  /// sendiri - kehadiran blok ini ialah keputusan backend.
  final AdminBlock? admin;

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
    member: MemberBlock.fromJson(_map(json['member'])),
    admin: json['admin'] == null
        ? null
        : AdminBlock.fromJson(_map(json['admin'])),
  );
}
