import 'package:flutter/widgets.dart';
import 'package:marc/shared/ui/form/mask_field.dart';

/// Topeng siap pakai. Tambah medan bertopeng baharu = tambah pemalar di
/// sini, bukan taburkan corak `####` merata dalam halaman.
///
/// TIADA topeng telefon Malaysia: nombor sah ada dua panjang (10 digit
/// `01X-XXX XXXX`, 11 digit untuk `011`), jadi satu topeng tetap akan
/// menolak taipan yang sah. Guna `normalizeMY` (shared/utils/phone.dart)
/// untuk medan telefon.
abstract final class AppMasks {
  /// Badan nombor ahli — awalan `MARC-` dihias di luar medan.
  /// Cth `0110/2026-0001`, `AB1C/2026-SA`.
  static const memberId = MaskConfig(
    mask: '****/####-****',
    upperCase: true,
    hint: '0110/2026-0001',
    prefixText: 'MARC-',
    keyboardType: TextInputType.text,
  );

  /// No. kad pengenalan Malaysia.
  static const icMY = MaskConfig(
    mask: '######-##-####',
    hint: '901231-14-5678',
    keyboardType: TextInputType.number,
  );

  /// Tarikh hari/bulan/tahun.
  static const date = MaskConfig(
    mask: '##/##/####',
    hint: '31/12/2026',
    keyboardType: TextInputType.datetime,
  );

  /// Poskod Malaysia.
  static const postcodeMY = MaskConfig(
    mask: '#####',
    hint: '43000',
    keyboardType: TextInputType.number,
  );
}
