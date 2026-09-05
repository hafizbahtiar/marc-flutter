import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/form/custom_textfield.dart';

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
}
