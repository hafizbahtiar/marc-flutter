import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/auth/login_page.dart';

class _SeededAuth extends AuthNotifier {
  _SeededAuth(AuthState initial) : super(TokenStorage()) {
    state = initial;
  }
}

Widget _app(AuthState auth) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith((ref) => _SeededAuth(auth)),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const LoginPage(),
    ),
  );
}

void main() {
  testWidgets(
    'endReason sessionEnded → dialog Sesi tamat, sekali sahaja',
    (tester) async {
      await tester.pumpWidget(
        _app(const AuthState(endReason: AuthEndReason.sessionEnded)),
      );
      await tester.pumpAndSettle();

      expect(find.text(sessionEndedTitle), findsOneWidget);
      expect(find.text(sessionEndedMessage), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(sessionEndedTitle), findsNothing);

      // Rebuild /login tak papar semula - consumeEndReason dah jalan.
      await tester.pumpWidget(
        _app(const AuthState(endReason: AuthEndReason.none)),
      );
      await tester.pumpAndSettle();
      expect(find.text(sessionEndedTitle), findsNothing);
    },
  );

  testWidgets('endReason signedOut → tiada dialog (tekan Log keluar)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const AuthState(endReason: AuthEndReason.signedOut)),
    );
    await tester.pumpAndSettle();

    expect(find.text(sessionEndedTitle), findsNothing);
    expect(find.text('Selamat kembali'), findsOneWidget);
  });

  testWidgets('endReason none → tiada dialog (buka app tanpa sesi)', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AuthState()));
    await tester.pumpAndSettle();

    expect(find.text(sessionEndedTitle), findsNothing);
  });
}
