/// Response `/donations/checkout` (marc_go, Stage 12) — backend pilih
/// gateway (Stripe sekarang; ToyyibPay/SociaBuzz akan datang) ikut
/// amount, client TAK boleh andaikan gateway apa. HANYA satu antara
/// [clientSecret]/[redirectUrl] terisi, ikut model gateway (padanan
/// `payment.CreateResult` union type di backend):
///   - clientSecret: gateway client-side confirm (Stripe)
///   - redirectUrl: gateway hosted-redirect page (ToyyibPay, SociaBuzz)
class DonationCheckoutResponse {
  const DonationCheckoutResponse({
    required this.gateway,
    this.clientSecret,
    this.redirectUrl,
  });

  final String gateway;
  final String? clientSecret;
  final String? redirectUrl;

  factory DonationCheckoutResponse.fromJson(Map<String, dynamic> json) {
    String? nonEmpty(String? v) => (v == null || v.isEmpty) ? null : v;
    return DonationCheckoutResponse(
      gateway: json['gateway'] as String,
      clientSecret: nonEmpty(json['client_secret'] as String?),
      redirectUrl: nonEmpty(json['redirect_url'] as String?),
    );
  }
}

enum DonationOutcome { success, cancelled, failure }

class DonationResult {
  const DonationResult(this.outcome, [this.message]);

  const DonationResult.success() : this(DonationOutcome.success);
  const DonationResult.cancelled() : this(DonationOutcome.cancelled);
  const DonationResult.failure(String message)
    : this(DonationOutcome.failure, message);

  final DonationOutcome outcome;
  final String? message;
}
