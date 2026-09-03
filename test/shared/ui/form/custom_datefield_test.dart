import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/form/custom_datefield.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  testWidgets('label luar + hint bila tiada nilai', (tester) async {
    await tester.pumpWidget(
      _host(
        CustomDateField(
          label: 'Tarikh lahir',
          hint: 'Pilih tarikh',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Tarikh lahir'), findsOneWidget);
    expect(find.text('Pilih tarikh'), findsOneWidget);
    final decorator = tester.widget<InputDecorator>(
      find.byType(InputDecorator),
    );
    expect(decorator.decoration.labelText, isNull);
  });

  testWidgets('nilai terisi dipapar, bukan hint', (tester) async {
    await tester.pumpWidget(
      _host(
        CustomDateField(
          label: 'Tarikh lahir',
          hint: 'Pilih tarikh',
          value: DateTime(2026, 9, 5),
          format: (dt) => '${dt.day}/${dt.month}/${dt.year}',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('5/9/2026'), findsOneWidget);
    expect(find.text('Pilih tarikh'), findsNothing);
  });

  testWidgets('ketuk buka date picker', (tester) async {
    await tester.pumpWidget(
      _host(
        CustomDateField(
          label: 'Tarikh lahir',
          hint: 'Pilih tarikh',
          onChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Pilih tarikh'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('validator Form papar ralat', (tester) async {
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      _host(
        Form(
          key: formKey,
          child: CustomDateField(
            label: 'Tarikh',
            hint: 'Pilih tarikh',
            validator: (v) => v == null ? 'Tarikh diperlukan' : null,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Tarikh diperlukan'), findsOneWidget);
  });
}
