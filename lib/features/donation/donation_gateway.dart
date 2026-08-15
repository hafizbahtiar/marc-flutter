import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/stripe.dart';
import 'donation_models.dart';

/// Kontrak sepunya setiap cara "selesaikan" donation lepas
/// `/donations/checkout` — cerminan `payment.Gateway` (interface) di
/// backend (`marc_go/internal/payment/payment.go`). Tambah gateway baru
/// (ToyyibPay/SociaBuzz, Stage 12) = implement class ni + daftar dalam
/// `donationCheckoutHandlersProvider`, `donation_page.dart` TAK perlu
/// ubah — ia cuma lookup handler ikut `response.gateway`.
abstract class DonationCheckoutHandler {
  const DonationCheckoutHandler();

  /// `context` diperlukan untuk baca `Theme.of(context)` semasa (light/
  /// dark ikut `themeModeProvider`) — gateway yang papar UI native
  /// sendiri (Stripe `PaymentSheet`) guna ni untuk padankan appearance,
  /// gateway redirect (`RedirectCheckoutHandler`) abaikan sahaja.
  Future<DonationResult> handle(
    BuildContext context,
    DonationCheckoutResponse response,
  );
}

/// Gateway client-side confirm (Stripe `PaymentSheet`) — satu sheet
/// native Stripe yang auto-papar SEMUA payment method aktif di dashboard
/// (kad, GrabPay, FPX kalau akaun layak), termasuk uruskan round-trip
/// redirect (`Stripe.urlScheme`, lihat `app/stripe.dart`) sendiri.
/// `returnURL` di bawah WAJIB: tanpanya PaymentSheet tapis SEMUA kaedah
/// berasaskan redirect (GrabPay, FPX) secara senyap. Gantikan
/// `CardFormField` manual (kad sahaja) — appearance dikawal
/// terus dari Dart (`PaymentSheetAppearance`), tak perlu native theme
/// hack macam `CardFormField` punya dropdown negara dulu.
class StripeCheckoutHandler extends DonationCheckoutHandler {
  const StripeCheckoutHandler();

  @override
  Future<DonationResult> handle(
    BuildContext context,
    DonationCheckoutResponse response,
  ) async {
    final clientSecret = response.clientSecret;
    if (clientSecret == null) {
      return const DonationResult.failure('Pembayaran tidak sah.');
    }

    // Baca tema SEBELUM sebarang await (context masih pasti valid di
    // sini — `donation_page.dart` dah `mounted` guard sebelum panggil).
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // PENTING: SETIAP field warna kena diisi eksplisit, jangan biar
    // mana-mana null. `PaymentSheetAppearanceColors` yang kita hantar
    // ialah SATU set rata (tiada sub-map light/dark), dan native SDK
    // memakainya sebagai override ATAS baseline `Colors.light()` /
    // `Colors.dark()` yang ia pilih ikut **night mode SISTEM**, bukan
    // `themeModeProvider` app. Jadi field yang tak diisi jatuh balik ke
    // baseline sistem: user yang set app ke Mod Gelap sedangkan OS masih
    // light akan dapat `componentText`/`placeholderText`/`icon` versi
    // light (teks hitam + placeholder kelabu) atas `componentBackground`
    // gelap — persis isu "sheet nampak light mode, teks tak nampak".
    // Isi semua = baseline sistem jadi tak relevan langsung.
    final appearanceColors = PaymentSheetAppearanceColors(
      primary: scheme.primary,
      background: scheme.surface,
      componentBackground: scheme.surfaceContainerHighest,
      componentBorder: scheme.outlineVariant,
      componentDivider: scheme.outlineVariant,
      componentText: scheme.onSurface,
      primaryText: scheme.onSurface,
      secondaryText: scheme.onSurfaceVariant,
      placeholderText: scheme.onSurfaceVariant,
      icon: scheme.onSurfaceVariant,
      error: scheme.error,
    );

    // Butang "Pay" ada set warna SENDIRI di native (bukan diturunkan
    // drpd `colors.primary`) — defaultnya teks PUTIH atas background
    // primary. Dalam mod gelap `scheme.primary` ialah hijau mint cerah
    // (#7FC79E), putih atasnya hampir tak terbaca. `light`/`dark`
    // kedua-duanya diisi dengan nilai yang sama (a) sebab pilihan
    // light-vs-dark native ikut sistem, bukan tema app, dan (b) iOS
    // reject kalau salah satu sahaja diisi.
    final buttonColors = PaymentSheetPrimaryButtonThemeColors(
      background: scheme.primary,
      text: scheme.onPrimary,
      border: scheme.primary,
    );

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'MARC',
          returnURL: stripeReturnUrl,
          // iOS sahaja — paksa userInterfaceStyle sheet ikut tema app
          // supaya chrome yang dilukis sistem (keyboard, nav bar) tak
          // tercabut drpd warna yang kita set di atas.
          style: isDark ? ThemeMode.dark : ThemeMode.light,
          appearance: PaymentSheetAppearance(
            colors: appearanceColors,
            shapes: const PaymentSheetShape(borderRadius: 12),
            primaryButton: PaymentSheetPrimaryButtonAppearance(
              colors: PaymentSheetPrimaryButtonTheme(
                light: buttonColors,
                dark: buttonColors,
              ),
            ),
          ),
        ),
      );
      await Stripe.instance.presentPaymentSheet();
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
  Future<DonationResult> handle(
    BuildContext context,
    DonationCheckoutResponse response,
  ) async {
    final url = response.redirectUrl;
    if (url == null) {
      return const DonationResult.failure('Pautan pembayaran tidak sah.');
    }

    // `Uri.tryParse` (bukan `Uri.parse`) — elak `FormatException` tak
    // ditangkap kalau backend/gateway pulangkan URL cacat. Skim
    // dihadkan `https` sahaja — `redirectUrl` ini akan lebih terdedah
    // kepada pengaruh gateway luar (ToyyibPay) berbanding Stripe
    // sekarang, jadi jangan benarkan skim lain (`javascript:`, custom
    // scheme, dsb.) dilancarkan terus.
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      return const DonationResult.failure('Pautan pembayaran tidak sah.');
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      return const DonationResult.failure('Gagal buka laman pembayaran.');
    }
    return const DonationResult.success();
  }
}
