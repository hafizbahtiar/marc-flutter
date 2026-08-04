import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc_flutter/widgets/auth_text_field.dart';

void main() {
  testWidgets('toggle obscure bila butang mata ditekan', (tester) async {
    final controller = TextEditingController(text: 'secret');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthTextField(
            controller: controller,
            label: 'Kata Laluan',
            icon: Icons.lock,
            obscureText: true,
          ),
        ),
      ),
    );

    // Awalnya tersembunyi
    final editable = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    expect(editable.obscureText, isTrue);

    // Tek butang toggle
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    // Sekarang terbuka
    final editableAfter = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    expect(editableAfter.obscureText, isFalse);
  });
}