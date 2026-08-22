import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/payments/payment_models.dart';

/// `MyPaymentHistory` ialah sempadan silang-repo: bentuknya ditetapkan
/// oleh `PaymentsHandler.Mine` dalam `../marc_go`. Yang diuji di sini
/// ialah nyahsiri, bukan UI — khususnya kelakuan bila server dan app
/// TAK sebaya, yang berlaku pada setiap deploy.

Map<String, dynamic> _regEntry() => {
  'id': '11111111-1111-1111-1111-111111111111',
  'amount_cents': 1000,
  'currency': 'myr',
  'gateway': 'toyyibpay',
  'status': 'succeeded',
  'created_at': '2026-08-22T10:00:00Z',
};

Map<String, dynamic> _donationEntry(String status) => {
  'id': '22222222-2222-2222-2222-222222222222',
  'amount_cents': 5000,
  'currency': 'myr',
  'gateway': 'stripe',
  'status': status,
  'created_at': '2026-08-22T11:00:00Z',
};

void main() {
  group('MyPaymentHistory.fromJson', () {
    test('menyahsiri ketiga-tiga senarai', () {
      final h = MyPaymentHistory.fromJson({
        'registration_fee': [_regEntry()],
        'activity_fees': <dynamic>[],
        'donations': [_donationEntry('succeeded')],
      });

      expect(h.registrationFee, hasLength(1));
      expect(h.activityFees, isEmpty);
      expect(h.donations, hasLength(1));
      expect(h.donations.single.amountCents, 5000);
      expect(h.donations.single.gateway, 'stripe');
    });

    // Deploy berperingkat: app BAHARU boleh mencapai backend LAMA yang
    // belum menghantar kunci `donations` (backend L33). Ia mesti
    // menyahsiri kepada senarai kosong, bukan terhempas — kalau tidak
    // skrin "Bayaran Saya" mati sepenuhnya sepanjang tetingkap deploy.
    test('kunci donations TIADA → senarai kosong, bukan terhempas', () {
      final h = MyPaymentHistory.fromJson({
        'registration_fee': [_regEntry()],
        'activity_fees': <dynamic>[],
      });

      expect(h.donations, isEmpty);
      expect(h.registrationFee, hasLength(1));
    });

    test('donations null dilayan sama seperti tiada', () {
      final h = MyPaymentHistory.fromJson({
        'registration_fee': <dynamic>[],
        'activity_fees': <dynamic>[],
        'donations': null,
      });

      expect(h.donations, isEmpty);
    });
  });

  group('DonationPaymentEntry', () {
    test('createdAt ditukar ke waktu tempatan', () {
      final e = DonationPaymentEntry.fromJson(_donationEntry('succeeded'));
      expect(e.createdAt.isUtc, isFalse);
      expect(e.createdAt, DateTime.parse('2026-08-22T11:00:00Z').toLocal());
    });

    // Status BUKAN 'succeeded' turut dipulangkan backend dgn sengaja —
    // sejarah patut menunjukkan percubaan yang gagal, bukan senyap
    // menghilangkannya. Gating butang resit berlaku di UI, jadi model
    // mesti membawa status apa pun tanpa menapisnya.
    test('membawa status pending dan failed', () {
      for (final s in ['pending', 'failed', 'succeeded']) {
        expect(DonationPaymentEntry.fromJson(_donationEntry(s)).status, s);
      }
    });
  });
}
