import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/form/custom_imagefield.dart';
import 'package:marc/shared/ui/media/app_network_image.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  testWidgets('label luar + tapak kosong', (tester) async {
    await tester.pumpWidget(
      _host(CustomImageField(label: 'Gambar sampul', onChanged: (_) {})),
    );

    expect(find.text('Gambar sampul'), findsOneWidget);
    expect(find.text('Tambah gambar'), findsOneWidget);
    expect(find.byType(AppNetworkImage), findsNothing);
  });

  testWidgets('previewUrl guna AppNetworkImage', (tester) async {
    await tester.pumpWidget(
      _host(
        CustomImageField(
          label: 'Gambar sampul',
          previewUrl: 'https://pub-test.r2.dev/cover.jpg',
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppNetworkImage), findsOneWidget);
    expect(find.text('Tambah gambar'), findsNothing);
  });

  testWidgets('pickImage inject memanggil onChanged', (tester) async {
    XFile? picked;
    final file = XFile.fromData(
      Uint8List.fromList(const [0xFF, 0xD8, 0xFF]),
      name: 'shot.jpg',
      mimeType: 'image/jpeg',
    );

    await tester.pumpWidget(
      _host(
        CustomImageField(
          label: 'Gambar sampul',
          pickImage: () async => file,
          onChanged: (v) => picked = v,
        ),
      ),
    );

    await tester.tap(find.text('Tambah gambar'));
    await tester.pump();
    expect(picked, same(file));
  });

  testWidgets('validator Form papar ralat bila tiada gambar', (tester) async {
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      _host(
        Form(
          key: formKey,
          child: CustomImageField(
            label: 'Gambar',
            validator: (v) => v == null ? 'Gambar diperlukan' : null,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Gambar diperlukan'), findsOneWidget);
  });
}
