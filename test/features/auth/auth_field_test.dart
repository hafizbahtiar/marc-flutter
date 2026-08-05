import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/auth/widgets/auth_field.dart';

void main() {
  testWidgets('toggle tunjuk/sembunyi menukar keterlihatan', (tester) async {
    final controller = TextEditingController(text: 'rahsia');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AuthField(
          controller: controller,
          label: 'Kata Laluan',
          obscureText: true,
        ),
      ),
    ));

    EditableText field() =>
        tester.widget<EditableText>(find.byType(EditableText));
    expect(field().obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });
}
