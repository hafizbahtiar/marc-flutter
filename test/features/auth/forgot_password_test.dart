import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/auth/forgot_password_page.dart';

/// Mesej selepas hantar MESTI neutral - ia sama sama ada akaun wujud
/// atau tidak. Kalau ia berbeza, UI membocorkan apa yang backend sengaja
/// sembunyikan (lihat L32: request pulang 204 sentiasa).
void main() {
  test('mesej selepas hantar tidak mengesahkan kewujudan akaun', () {
    final m = forgotPasswordSentMessage.toLowerCase();

    expect(m, contains('kalau'));
    for (final bocor in ['tidak dijumpai', 'tak wujud', 'berjaya dihantar']) {
      expect(
        m,
        isNot(contains(bocor)),
        reason:
            'mesej mengesahkan kewujudan akaun: "$forgotPasswordSentMessage"',
      );
    }
  });
}
