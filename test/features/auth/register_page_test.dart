import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/auth/register_page.dart';
import 'package:marc/shared/ui/form/custom_textfield.dart';

Future<void> pumpRegisterPage(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.light, home: const RegisterPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterStaffId(WidgetTester tester, String value) async {
  await tester.enterText(
    find.descendant(
      of: find.widgetWithText(CustomTextField, 'Nombor Staff'),
      matching: find.byType(TextField),
    ),
    value,
  );
}

void main() {
  testWidgets('shows validation error when staff ID is empty', (tester) async {
    await pumpRegisterPage(tester);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('Nombor staff wajib diisi'), findsOneWidget);
  });

  testWidgets('shows validation error when staff ID exceeds 64 chars', (
    tester,
  ) async {
    await pumpRegisterPage(tester);
    await _enterStaffId(tester, 'x' * 65);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(
      find.text('Nombor staff tidak boleh lebih 64 aksara'),
      findsOneWidget,
    );
  });

  testWidgets('shows validation error when staff ID contains a slash', (
    tester,
  ) async {
    await pumpRegisterPage(tester);
    await _enterStaffId(tester, 'EMP/001');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(
      find.text("Nombor staff tidak boleh mengandungi '/'"),
      findsOneWidget,
    );
  });
}
