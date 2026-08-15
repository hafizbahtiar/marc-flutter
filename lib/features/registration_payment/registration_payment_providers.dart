import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';

/// Dilempar oleh [RegistrationPaymentRepository.checkout] bila backend
/// pulangkan `code: "phone_required"` — ahli `pending` yang mendaftar
/// SEBELUM phone jadi wajib (`/auth/register`) belum ada nombor telefon
/// pada profil, dan ToyyibPay `billPhone` WAJIB bukan-kosong. Caller
/// (UI) tangkap ini secara khusus untuk papar dialog minta nombor,
/// bukan snackbar ralat generik.
class PhoneRequiredException implements Exception {}

/// `/registration-payments/checkout` — protected by `RequireAuth` sahaja
/// (bukan `RequireApprovedStatus`), jadi ahli `pending` BOLEH panggil ni
/// untuk bayar yuran pendaftaran sebelum diluluskan. Backend pulangkan
/// 400 kalau ahli dah approved (tak perlu bayar) atau dah bayar, `code:
/// "phone_required"` (lihat [PhoneRequiredException]) kalau profil tiada
/// phone, atau 503 kalau gateway belum dikonfigurasi (kredential
/// ToyyibPay sandbox/prod belum diisi). Pengesahan pembayaran sebenar
/// berlaku async via webhook backend — Flutter tak pernah tahu "berjaya"
/// terus, ahli kena kembali ke app dan tekan "Semak semula" untuk lihat
/// status terkini.
final registrationPaymentRepositoryProvider =
    Provider<RegistrationPaymentRepository>(
      (ref) => RegistrationPaymentRepository(ref),
    );

class RegistrationPaymentRepository {
  RegistrationPaymentRepository(this._ref);
  final Ref _ref;

  /// [phone] pilihan — cuma perlu bila panggilan pertama (tanpa phone)
  /// lempar [PhoneRequiredException]. Pulangkan `redirect_url` sahaja —
  /// bentuk respons backend cuma satu field, jadi tak perlu model class
  /// berasingan (bandingkan `DonationCheckoutResponse` yang ada
  /// berbilang field ikut gateway).
  Future<String> checkout({String? phone}) async {
    final dio = _ref.read(dioProvider);
    try {
      final res = await dio.post(
        '/registration-payments/checkout',
        data: phone != null ? {'phone': phone} : null,
      );
      return res.data['redirect_url'] as String;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['code'] == 'phone_required') {
        throw PhoneRequiredException();
      }
      rethrow;
    }
  }
}
