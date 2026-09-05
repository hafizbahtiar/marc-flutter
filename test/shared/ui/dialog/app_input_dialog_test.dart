import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';
import 'package:marc/shared/ui/form/app_masks.dart';
import 'package:marc/shared/ui/form/mask_field.dart';

Future<String?> _open(
  WidgetTester tester, {
  required MaskConfig preset,
  String initialValue = '',
}) async {
  String? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showAppInputDialog(
                context,
                title: 'Betulkan Nombor Ahli',
                positiveLabel: 'Simpan',
                initialValue: initialValue,
                maskPreset: preset,
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('maskPreset topeng taipan dan papar awalan', (tester) async {
    await _open(tester, preset: AppMasks.memberId);

    expect(find.text('MARC-'), findsOneWidget);
    expect(find.text(AppMasks.memberId.hint!), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ab1c2026sa');
    await tester.pump();

    expect(find.text('AB1C/2026-SA'), findsOneWidget);
  });

  testWidgets('maskPreset topeng initialValue', (tester) async {
    await _open(tester, preset: AppMasks.memberId, initialValue: 'ab1c2026sa');

    expect(find.text('AB1C/2026-SA'), findsOneWidget);
  });
}
