import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';

/// Anggaran fi transaksi gateway (RM1.00) untuk digunakan bila
/// [paymentConfigProvider] gagal/backend lama belum sokong
/// `GET /payment-config` - supaya breakdown invoice tetap kelihatan
/// munasabah semasa version skew, bukan hilang terus. BUKAN nilai yang
/// dihantar ke gateway sebenar (itu `CheckoutRequest.amountCents`, tak
/// disentuh) - sekadar anggaran paparan.
const kDefaultGatewayChargeCents = 100;

/// `GET /payment-config` - SATU sumber nilai config checkout GENERIK
/// (bukan spesifik yuran pendaftaran/aktiviti). TAK PERNAH throw:
/// kegagalan (network/backend lama tiada endpoint ni) pulang
/// [kDefaultGatewayChargeCents], caller (CheckoutPage) tak perlu uruskan
/// error state - cuma `.valueOrNull ?? kDefaultGatewayChargeCents`.
///
/// `.autoDispose` SENGAJA - bukan `FutureProvider` biasa. `catch`
/// menukar SETIAP kegagalan (network putus, backend lama tiada route
/// ni) jadi nilai BERJAYA (`kDefaultGatewayChargeCents`), dan Riverpod
/// cache nilai berjaya SELAMA-LAMANYA untuk provider biasa - sekali
/// ahli buka checkout semasa offline, seluruh app run tu terperangkap
/// pada anggaran fallback walau rangkaian pulih kemudian. `autoDispose`
/// buang provider (dan cache-nya) sebaik `CheckoutPage` ditutup (tiada
/// listener lagi), jadi checkout SETERUSNYA cuba fetch semula dari awal
/// (Opus verify 2026-08-24).
final paymentConfigProvider = FutureProvider.autoDispose<int>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final res = await dio.get('/payment-config');
    final cents = (res.data['gateway_charge_cents'] as num?)?.toInt();
    return cents ?? kDefaultGatewayChargeCents;
  } catch (_) {
    return kDefaultGatewayChargeCents;
  }
});
