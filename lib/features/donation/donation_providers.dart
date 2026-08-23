import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';

import 'donation_gateway.dart';
import 'donation_models.dart';

/// Registry handler ikut nama gateway (padanan key `gateways` map di
/// backend `cmd/api/main.go`). Tambah ToyyibPay/SociaBuzz (Stage 12,
/// akan datang) = tambah entry sini, `donation_page.dart` TAK perlu
/// ubah - ia cuma lookup `handlers[response.gateway]`.
final donationCheckoutHandlersProvider =
    Provider<Map<String, DonationCheckoutHandler>>((ref) {
      return const {
        'stripe': StripeCheckoutHandler(),
        // 'toyyibpay': RedirectCheckoutHandler(),
        // 'sociabuzz': RedirectCheckoutHandler(),
      };
    });

final donationRepositoryProvider = Provider<DonationRepository>(
  (ref) => DonationRepository(ref),
);

class DonationRepository {
  DonationRepository(this._ref);
  final Ref _ref;

  /// `/donations/checkout` - route AWAM (dioProvider tetap lampir
  /// Bearer token kalau user log masuk, backend kaitkan `user_id`
  /// automatik via OptionalAuth; kalau tak log masuk, `donorEmail`
  /// WAJIB - backend tolak 400 kalau kosong).
  Future<DonationCheckoutResponse> checkout({
    required int amountCents,
    String? donorName,
    String? donorEmail,
  }) async {
    final dio = _ref.read(dioProvider);
    final res = await dio.post(
      '/donations/checkout',
      data: {
        'amount_cents': amountCents,
        'donor_name': ?donorName,
        'donor_email': ?donorEmail,
      },
    );
    return DonationCheckoutResponse.fromJson(res.data as Map<String, dynamic>);
  }
}
