import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';

/// `/registration-payments/checkout` — protected by `RequireAuth` sahaja
/// (bukan `RequireApprovedStatus`), jadi ahli `pending` BOLEH panggil ni
/// untuk bayar yuran pendaftaran sebelum diluluskan. Backend pulangkan
/// 400 kalau ahli dah approved (tak perlu bayar) atau dah bayar, atau
/// 503 kalau gateway belum dikonfigurasi (kredential ToyyibPay sandbox/
/// prod belum diisi). Pengesahan pembayaran sebenar berlaku async via
/// webhook backend — Flutter tak pernah tahu "berjaya" terus, ahli kena
/// kembali ke app dan tekan "Semak semula" untuk lihat status terkini.
final registrationPaymentRepositoryProvider =
    Provider<RegistrationPaymentRepository>(
      (ref) => RegistrationPaymentRepository(ref),
    );

class RegistrationPaymentRepository {
  RegistrationPaymentRepository(this._ref);
  final Ref _ref;

  /// Pulangkan `redirect_url` sahaja — bentuk respons backend cuma satu
  /// field, jadi tak perlu model class berasingan (bandingkan
  /// `DonationCheckoutResponse` yang ada berbilang field ikut gateway).
  Future<String> checkout() async {
    final dio = _ref.read(dioProvider);
    final res = await dio.post('/registration-payments/checkout');
    return res.data['redirect_url'] as String;
  }
}
