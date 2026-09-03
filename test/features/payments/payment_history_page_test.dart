import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/payments/payment_history_page.dart';
import 'package:marc/features/payments/payment_models.dart';
import 'package:marc/features/payments/payment_providers.dart';

Future<void> pumpPaymentHistoryPage(
  WidgetTester tester, {
  required bool outstandingRegistrationFee,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myPaymentHistoryProvider.overrideWith(
          (ref) async => MyPaymentHistory(
            registrationFee: const [],
            activityFees: const [],
            donations: const [],
            outstandingRegistrationFee: outstandingRegistrationFee,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const PaymentHistoryPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows outstanding fee banner when flag is true', (tester) async {
    await pumpPaymentHistoryPage(tester, outstandingRegistrationFee: true);
    expect(find.text('Yuran pendaftaran belum dibayar'), findsOneWidget);
    expect(find.text('Tiada sejarah bayaran.'), findsNothing);
  });

  testWidgets('hides outstanding fee banner when flag is false', (
    tester,
  ) async {
    await pumpPaymentHistoryPage(tester, outstandingRegistrationFee: false);
    expect(find.text('Yuran pendaftaran belum dibayar'), findsNothing);
    expect(find.text('Tiada sejarah bayaran.'), findsOneWidget);
  });
}
