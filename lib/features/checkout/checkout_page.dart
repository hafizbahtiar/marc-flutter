import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/checkout/checkout_providers.dart';
import 'package:marc/features/registration_payment/registration_payment_providers.dart'
    show PhoneRequiredException;
import 'package:marc/shared/phone.dart';
import 'package:marc/shared/validators.dart';
import 'package:marc/shared/widgets/edit_text_dialog.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Padan pola `_formatAmount` di fail-fail lain (`payment_history_page.dart`,
/// `my_activities_page.dart`) - duplikasi sengaja, satu fungsi kecil, tak
/// berbaloi jadi kebergantungan silang-fail.
String _formatAmount(int cents, String currency) =>
    '${currency.toUpperCase()} ${(cents / 100).toStringAsFixed(2)}';

/// Kontrak generik satu checkout gateway hosted-redirect (ToyyibPay hari
/// ni, mana-mana gateway serupa kelak) - [CheckoutPage] TAK TAHU langsung
/// pasal ToyyibPay/yuran pendaftaran/yuran aktiviti, cuma panggil
/// [onCheckout] dan uruskan hasilnya. Caller (feature lain) bina
/// [CheckoutRequest] sendiri dan `context.push('/checkout', extra: ...)`.
///
/// [onCheckout] pulangkan `redirect_url` (String) - padan bentuk respons
/// backend `POST .../checkout` sedia ada
/// (`registration_payment_providers.dart`, `activity_providers.dart`).
/// [phone] dihantar semula bila caller pertama kali lempar
/// [PhoneRequiredException] (ahli lama tanpa nombor telefon pada profil).
class CheckoutRequest {
  const CheckoutRequest({
    required this.title,
    required this.amountCents,
    required this.currency,
    required this.onCheckout,
    this.description,
  });

  final String title;

  /// Jumlah (sen) - `null` bila caller tak pasti jumlah sebenar (cth
  /// respons backend versi lama belum hantar medan ni, lihat
  /// `Profile.registrationFeeCents`/`MyRegistration.feeCents`). SENGAJA
  /// bukan `int` dengan lalai `0` - `0` bermaksud "percuma", bukan
  /// "tak diketahui", dan dua makna tu tak boleh digabung tanpa risiko
  /// papar "MYR 0.00" yang mengelirukan untuk caj yang sebenarnya bukan
  /// sifar (Opus verify 2026-08-24).
  final int? amountCents;
  final String currency;
  final String? description;
  final Future<String> Function({String? phone}) onCheckout;
}

/// Skrin checkout REUSABLE - satu-satunya tempat yang uruskan
/// phone-prompt, panggilan checkout, validasi URL (https sahaja), dan
/// buka pelayar luar. Sebelum ni logik ni diduplikasi di
/// `_PendingStatusView` (`feed_page.dart`, yuran pendaftaran) dan
/// `_RegistrationCardState` (`my_activities_page.dart`, yuran
/// aktiviti) - kedua-dua caller kini cuma bina [CheckoutRequest] dan
/// push route ni.
///
/// Pengesahan pembayaran SEBENAR berlaku async via webhook backend -
/// page ni TAK memantau status, cuma "mulakan bayaran" lalu `pop` balik
/// ke skrin asal (yang dah ada butang "Semak semula"/pull-to-refresh
/// sendiri).
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, required this.request});

  final CheckoutRequest request;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  bool _submitting = false;

  /// Papar dialog minta nombor telefon (ahli lama yang daftar SEBELUM
  /// phone jadi wajib - lihat [PhoneRequiredException]). Pulang nombor
  /// TERNORMAL atau `null` kalau dibatal/tak sah - caller MESTI berhenti
  /// (bukan cuba checkout lagi) bila `null`.
  Future<String?> _promptPhone() async {
    final raw = await showEditTextDialog(
      context,
      title: 'Nombor Telefon',
      initialValue: '',
      maxLines: 1,
    );
    if (raw == null) return null; // dibatal
    final error = validatePhone(raw);
    if (error != null) {
      if (!mounted) return null;
      MySnackBar.error(context, error);
      return null;
    }
    return normalizeMY(raw);
  }

  Future<void> _pay() async {
    setState(() => _submitting = true);
    try {
      String url;
      try {
        url = await widget.request.onCheckout();
      } on PhoneRequiredException {
        if (!mounted) return;
        final phone = await _promptPhone();
        if (phone == null) return;
        if (!mounted) return;
        url = await widget.request.onCheckout(phone: phone);
      }

      // Padanan corak `RedirectCheckoutHandler.handle()`
      // (`lib/features/donation/donation_gateway.dart`): `Uri.tryParse`
      // (bukan `Uri.parse`, elak `FormatException` tak ditangkap), skim
      // dihadkan `https` sahaja, `launchUrl` external + semak nilai bool.
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https') {
        if (!mounted) return;
        MySnackBar.error(context, 'Pautan pembayaran tidak sah.');
        return;
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        if (!mounted) return;
        MySnackBar.error(context, 'Gagal buka laman pembayaran.');
        return;
      }

      if (!mounted) return;
      MySnackBar.success(
        context,
        'Selesaikan pembayaran dalam pelayar, kemudian semak semula status di sini.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      MySnackBar.error(
        context,
        e is DioException
            ? extractErrorMessage(e)
            : 'Gagal proses pembayaran. Cuba lagi.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final req = widget.request;
    // `.valueOrNull ?? kDefaultGatewayChargeCents` - papar anggaran
    // SERTA-MERTA (tiada spinner menunggu fetch), update automatik bila
    // nilai sebenar backend siap dimuat. Tak pernah null/error sendiri
    // (lihat `paymentConfigProvider` - fallback dibina dalam provider).
    final gatewayChargeCents =
        ref.watch(paymentConfigProvider).valueOrNull ??
        kDefaultGatewayChargeCents;

    return Scaffold(
      appBar: AppBar(title: Text(req.title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                if (req.description != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      req.description!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                // `amountCents == null` - jumlah tak diketahui (respons
                // backend lama), bukan percuma. Elak "MYR 0.00" yang
                // mengelirukan (Opus verify 2026-08-24). Bila diketahui,
                // pecah invoice-style ("Yuran" + "Caj Pemprosesan" =
                // "Jumlah") HANYA kalau jumlah cukup besar drpd caj
                // gateway - di bawah/sama, breakdown jadi "Yuran RM0.00"
                // atau negatif yang mengelirukan, papar jumlah sahaja.
                if (req.amountCents != null)
                  _InvoiceCard(
                    totalCents: req.amountCents!,
                    gatewayChargeCents: gatewayChargeCents,
                    currency: req.currency,
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _pay,
                    child: _submitting
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator.adaptive(),
                          )
                        : const Text('Bayar Sekarang'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Breakdown invoice - kad dengan baris "Yuran"/"Caj Pemprosesan
/// Pembayaran" (kalau jumlah cukup besar) atau "Jumlah Perlu Dibayar"
/// sahaja (kes tepi). `totalCents` KEKAL jumlah SEBENAR yang dihantar ke
/// gateway (`CheckoutRequest.amountCents`, tak disentuh) - kad ni cuma
/// PECAHKAN paparan, bukan ubah logik caj.
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.totalCents,
    required this.gatewayChargeCents,
    required this.currency,
  });

  final int totalCents;
  final int gatewayChargeCents;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final showBreakdown = totalCents > gatewayChargeCents;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (showBreakdown) ...[
              _InvoiceRow(
                label: 'Yuran',
                amount: _formatAmount(
                  totalCents - gatewayChargeCents,
                  currency,
                ),
              ),
              const SizedBox(height: 8),
              _InvoiceRow(
                label: 'Caj Pemprosesan Pembayaran',
                amount: _formatAmount(gatewayChargeCents, currency),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
            ],
            _InvoiceRow(
              label: 'Jumlah Perlu Dibayar',
              amount: _formatAmount(totalCents, currency),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  final String label;
  final String amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = emphasize
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );
    final amountStyle = emphasize
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(amount, style: amountStyle),
      ],
    );
  }
}
