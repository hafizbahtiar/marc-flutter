import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';

import 'donation_models.dart';

/// Kontrak sepunya setiap cara "selesaikan" donation lepas
/// `/donations/checkout` — cerminan `payment.Gateway` (interface) di
/// backend (`marc_go/internal/payment/payment.go`). Tambah gateway baru
/// (ToyyibPay/SociaBuzz, Stage 12) = implement class ni + daftar dalam
/// `donationCheckoutHandlersProvider`, `donation_page.dart` TAK perlu
/// ubah — ia cuma lookup handler ikut `response.gateway`.
abstract class DonationCheckoutHandler {
  const DonationCheckoutHandler();

  Future<DonationResult> handle(DonationCheckoutResponse response);
}

/// Gateway client-side confirm (Stripe Payment Element) — anggap
/// `CardFormField` di `donation_page.dart` dah dipaparkan & diisi
/// sebelum `handle()` dipanggil; SDK Stripe baca terus dari form yang
/// sedang mounted, tak perlu lalu data kad eksplisit di sini.
class StripeCheckoutHandler extends DonationCheckoutHandler {
  const StripeCheckoutHandler();

  @override
  Future<DonationResult> handle(DonationCheckoutResponse response) async {
    final clientSecret = response.clientSecret;
    if (clientSecret == null) {
      return const DonationResult.failure('Pembayaran tidak sah.');
    }

    try {
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );
      return const DonationResult.success();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return const DonationResult.cancelled();
      }
      return DonationResult.failure(
        e.error.localizedMessage ?? 'Pembayaran gagal.',
      );
    } catch (_) {
      return const DonationResult.failure('Pembayaran gagal. Cuba lagi.');
    }
  }
}

/// Gateway hosted-redirect (ToyyibPay, SociaBuzz — akan datang) — buka
/// `redirectUrl` dalam browser luar. Status pembayaran sebenar
/// ditentukan webhook backend (bukan client), jadi "success" di sini
/// cuma bermaksud redirect berjaya dibuka — TAK sama dengan pembayaran
/// berjaya.
class RedirectCheckoutHandler extends DonationCheckoutHandler {
  const RedirectCheckoutHandler();

  @override
  Future<DonationResult> handle(DonationCheckoutResponse response) async {
    final url = response.redirectUrl;
    if (url == null) {
      return const DonationResult.failure('Pautan pembayaran tidak sah.');
    }

    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      return const DonationResult.failure('Gagal buka laman pembayaran.');
    }
    return const DonationResult.success();
  }
}
