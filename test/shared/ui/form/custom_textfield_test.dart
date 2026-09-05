import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/form/app_masks.dart';
import 'package:marc/shared/ui/form/custom_textfield.dart';
import 'package:marc/shared/ui/form/mask_field.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('mask format semasa taip', (tester) async {
    await tester.pumpWidget(_host(const CustomTextField(mask: '##/##')));

    await tester.enterText(find.byType(TextFormField), '1234');
    await tester.pump();

    expect(find.text('12/34'), findsOneWidget);
  });

  testWidgets('initialValue ikut topeng', (tester) async {
    await tester.pumpWidget(
      _host(const CustomTextField(mask: '##/##', initialValue: '1234')),
    );

    expect(find.text('12/34'), findsOneWidget);
  });

  testWidgets('maskPreset bawa topeng, hint dan papan kekunci', (tester) async {
    await tester.pumpWidget(
      _host(const CustomTextField(maskPreset: AppMasks.icMY)),
    );

    expect(find.text(AppMasks.icMY.hint!), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.number);

    await tester.enterText(find.byType(TextFormField), '880102105566');
    await tester.pump();
    expect(find.text('880102-10-5566'), findsOneWidget);
  });

  testWidgets('hint sendiri mengatasi hint preset', (tester) async {
    await tester.pumpWidget(
      _host(const CustomTextField(maskPreset: AppMasks.icMY, hint: 'No. KP')),
    );

    expect(find.text('No. KP'), findsOneWidget);
    expect(find.text(AppMasks.icMY.hint!), findsNothing);
  });

  testWidgets('maskPreset memberId auto huruf besar', (tester) async {
    await tester.pumpWidget(
      _host(const CustomTextField(maskPreset: AppMasks.memberId)),
    );

    await tester.enterText(find.byType(TextFormField), 'ab1c2026sa');
    await tester.pump();

    expect(find.text('AB1C/2026-SA'), findsOneWidget);
  });

  testWidgets('onUnmaskedChanged bagi teks tanpa pemisah', (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(
      _host(CustomTextField(mask: '##/##', onUnmaskedChanged: seen.add)),
    );

    await tester.enterText(find.byType(TextFormField), '1234');
    await tester.pump();

    expect(seen.last, '1234');
  });

  testWidgets('maskRequiredMessage gagal bila topeng belum penuh', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: const CustomTextField(
            mask: '##/##',
            maskRequiredMessage: 'Isi penuh',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '12');
    await tester.pump();
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Isi penuh'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '1234');
    await tester.pump();
    expect(key.currentState!.validate(), isTrue);
  });

  testWidgets('validator sendiri didahulukan daripada maskRequiredMessage', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: CustomTextField(
            mask: '##/##',
            maskRequiredMessage: 'Isi penuh',
            validator: (v) => v!.isEmpty ? 'Wajib' : null,
          ),
        ),
      ),
    );

    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Wajib'), findsOneWidget);
    expect(find.text('Isi penuh'), findsNothing);
  });

  testWidgets('controller ditetapkan dari luar ditopeng', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(CustomTextField(mask: '##/##', controller: controller)),
    );

    controller.text = '1234';
    await tester.pump();

    expect(controller.text, '12/34');
    expect(find.text('12/34'), findsOneWidget);
  });

  testWidgets('maskController dedah teks mentah dan status penuh', (
    tester,
  ) async {
    final mask = MaskFieldController();
    await tester.pumpWidget(
      _host(CustomTextField(mask: '##/##', maskController: mask)),
    );

    await tester.enterText(find.byType(TextFormField), '12');
    await tester.pump();
    expect(mask.unmaskedText, '12');
    expect(mask.isFill, isFalse);

    await tester.enterText(find.byType(TextFormField), '1234');
    await tester.pump();
    expect(mask.unmaskedText, '1234');
    expect(mask.maskedText, '12/34');
    expect(mask.isFill, isTrue);
  });

  testWidgets('tukar maskFilter membina semula topeng', (tester) async {
    Widget build(RegExp pattern) =>
        _host(CustomTextField(mask: '***', maskFilter: {'*': pattern}));

    await tester.pumpWidget(build(RegExp(r'[A-Z]')));
    await tester.enterText(find.byType(TextFormField), 'AB1');
    await tester.pump();
    expect(find.text('AB'), findsOneWidget);

    await tester.pumpWidget(build(RegExp(r'[A-Z0-9]')));
    await tester.enterText(find.byType(TextFormField), 'AB1');
    await tester.pump();
    expect(find.text('AB1'), findsOneWidget);
  });
}
