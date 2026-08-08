import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// URL scheme khusus app ni untuk redirect-based payment methods
/// (FPX — bank Malaysia — perlukan round-trip keluar app untuk
/// authenticate, pastu balik). MESTI padan dengan intent-filter
/// (AndroidManifest.xml) + CFBundleURLTypes (Info.plist).
const stripeReturnUrl = 'marc://stripe-redirect';

/// Init Stripe SDK (donation, Stage 12).
///
/// Lompat senyap kalau `STRIPE_PUBLISHABLE_KEY` belum diisi dalam
/// `.env` — padanan pattern [initOneSignal], app tetap boleh jalan
/// waktu pembangunan tanpa kredential (donation page je disabled).
Future<void> initStripe() async {
  final publishableKey = dotenv.maybeGet('STRIPE_PUBLISHABLE_KEY') ?? '';
  if (publishableKey.isEmpty) return;

  Stripe.publishableKey = publishableKey;
  Stripe.urlScheme = 'marc';
  await Stripe.instance.applySettings();
}
