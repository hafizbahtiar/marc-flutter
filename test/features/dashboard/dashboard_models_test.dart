import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/dashboard/dashboard_models.dart';

void main() {
  group('DashboardData.fromJson', () {
    test('payload minimum tanpa kunci admin → admin null, senarai kosong', () {
      final data = DashboardData.fromJson({
        'member': {
          'membership': {'status': 'approved'},
        },
      });

      expect(data.admin, isNull);
      expect(data.member.openActivities, isEmpty);
      expect(data.member.certificatesTotal, 0);
      expect(data.member.totalMembers, 0);
      expect(data.member.membership.status, 'approved');
      expect(data.member.membership.memberId, isNull);
      expect(data.member.membership.outstandingFeeCents, isNull);
    });

    test('medan tidak dikenali diabaikan, tidak melontar', () {
      expect(
        () => DashboardData.fromJson({
          'member': {
            'membership': {'status': 'approved', 'medan_masa_depan': 42},
            'medan_baharu': {'apa': 'ini'},
          },
          'admin': null,
          'aras_atas_baharu': [1, 2, 3],
        }),
        returnsNormally,
      );
    });

    test('blok admin dihurai penuh', () {
      final data = DashboardData.fromJson({
        'member': {
          'membership': {'status': 'approved'},
        },
        'admin': {
          'pending_approvals': 5,
          'revenue_this_month': {
            'currency': 'MYR',
            'registration_cents': 30000,
            'activity_cents': 12500,
            'donation_cents': null,
            'total_cents': 42500,
          },
          'member_stats': {
            'active': 312,
            'pending': 5,
            'new_this_month': 18,
            'by_department': [
              {'code': 'KL', 'name': 'Kuala Lumpur', 'count': 90},
            ],
          },
          'activity_stats': {
            'upcoming': 4,
            'registrations_this_month': 87,
            'attendance_rate': 0.72,
          },
        },
      });

      final admin = data.admin!;
      expect(admin.pendingApprovals, 5);
      expect(admin.revenue.donationCents, isNull);
      expect(admin.revenue.totalCents, 42500);
      expect(admin.memberStats.byDepartment.single.name, 'Kuala Lumpur');
      expect(admin.activityStats.attendanceRate, 0.72);
    });

    test('attendance_rate null dikekalkan sebagai null (bukan 0)', () {
      final data = DashboardData.fromJson({
        'member': {
          'membership': {'status': 'approved'},
        },
        'admin': {
          'activity_stats': {'attendance_rate': null},
        },
      });

      expect(data.admin!.activityStats.attendanceRate, isNull);
    });

    test('aktiviti dihurai dengan tarikh', () {
      final data = DashboardData.fromJson({
        'member': {
          'membership': {'status': 'approved'},
          'open_activities': [
            {
              'id': 'a1',
              'title': 'Bengkel',
              'starts_at': '2026-09-10T09:00:00Z',
              'category_name': 'Latihan',
              'fee_cents': 2000,
              'currency': 'myr',
              'registration_count': 4,
            },
          ],
        },
      });

      final a = data.member.openActivities.single;
      expect(a.id, 'a1');
      expect(a.startsAt.toUtc().hour, 9);
      expect(a.feeCents, 2000);
    });

    // Backend berhenti menghantar medan ini, tetapi app di telefon ahli
    // mungkin bercakap dengan backend LAMA yang masih menghantarnya.
    // Medan tak dikenali mesti diabaikan, bukan meranapkan skrin Utama.
    test('payload backend lama dengan medan dibuang → diabaikan', () {
      expect(
        () => DashboardData.fromJson({
          'member': {
            'membership': {'status': 'approved'},
            'unread_notifications': 4,
            'upcoming_registrations': [
              {'id': 'r1', 'activity_id': 'a1', 'title': 'Bengkel'},
            ],
          },
        }),
        returnsNormally,
      );
    });
  });
}
