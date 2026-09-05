import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/dialog/app_dialog_field.dart';
import 'package:marc/shared/ui/form/app_masks.dart';
import 'package:marc/shared/ui/form/custom_textfield.dart';
import 'package:marc/shared/ui/form/mask_field.dart';

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

  testWidgets('iOS: topeng jalan dalam CupertinoTextField', (tester) async {
    await tester.pumpWidget(
      _host(TargetPlatform.iOS, field: const AppDialogTextField(mask: '##/##')),
    );

    await tester.enterText(find.byType(CupertinoTextField), '1234');
    await tester.pump();

    expect(find.text('12/34'), findsOneWidget);
  });

  testWidgets('iOS: maskPreset bawa topeng, hint dan papan kekunci', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TargetPlatform.iOS,
        field: const AppDialogTextField(maskPreset: AppMasks.icMY),
      ),
    );

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.placeholder, AppMasks.icMY.hint);
    expect(field.keyboardType, TextInputType.number);

    await tester.enterText(find.byType(CupertinoTextField), '880102105566');
    await tester.pump();
    expect(find.text('880102-10-5566'), findsOneWidget);
  });

  testWidgets('iOS: onUnmaskedChanged dan maskController', (tester) async {
    final mask = MaskFieldController();
    final seen = <String>[];
    await tester.pumpWidget(
      _host(
        TargetPlatform.iOS,
        field: AppDialogTextField(
          mask: '##/##',
          maskController: mask,
          onUnmaskedChanged: seen.add,
        ),
      ),
    );

    await tester.enterText(find.byType(CupertinoTextField), '1234');
    await tester.pump();

    expect(seen.last, '1234');
    expect(mask.unmaskedText, '1234');
    expect(mask.isFill, isTrue);
  });

  testWidgets('Material: preset diteruskan ke CustomTextField', (tester) async {
    await tester.pumpWidget(
      _host(
        TargetPlatform.android,
        field: const AppDialogTextField(maskPreset: AppMasks.memberId),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'ab1c2026sa');
    await tester.pump();

    expect(find.text('AB1C/2026-SA'), findsOneWidget);
    expect(find.text('MARC-'), findsOneWidget);
  });

  testWidgets('iOS: controller ditetapkan dari luar ditopeng', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        TargetPlatform.iOS,
        field: AppDialogTextField(mask: '##/##', controller: controller),
      ),
    );

    controller.text = '1234';
    await tester.pump();

    expect(controller.text, '12/34');
  });
}
