import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/dialog/app_dialog_field.dart';
import 'package:marc/shared/ui/form/custom_textfield.dart';

Widget _host(TargetPlatform platform, {required Widget field}) {
  return MaterialApp(
    theme: AppTheme.light.copyWith(platform: platform),
    home: Scaffold(body: field),
  );
}

void main() {
  testWidgets('Material: AppDialogTextField guna CustomTextField', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TargetPlatform.android,
        field: const AppDialogTextField(label: 'Kod', hint: 'BKP'),
      ),
    );

    expect(find.byType(CustomTextField), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsNothing);
    expect(find.text('Kod'), findsOneWidget);
  });

  testWidgets('iOS: AppDialogTextField guna CupertinoTextField + label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TargetPlatform.iOS,
        field: const AppDialogTextField(label: 'Kod', hint: 'BKP'),
      ),
    );

    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(find.byType(CustomTextField), findsNothing);
    expect(find.text('Kod'), findsOneWidget);
  });
}
