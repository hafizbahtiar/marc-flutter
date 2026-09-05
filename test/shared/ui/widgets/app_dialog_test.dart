import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';
import 'package:marc/shared/ui/dialog/confirm_dialog.dart';
import 'package:marc/shared/ui/dialog/edit_text_dialog.dart';
import 'package:marc/shared/ui/form/custom_textfield.dart';
import 'package:marc/shared/ui/sheet/app_form_sheet.dart';

Widget _host(TargetPlatform platform, void Function(BuildContext) onTap) {
  return MaterialApp(
    theme: AppTheme.light.copyWith(platform: platform),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => onTap(context),
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  );
}

void _phoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Size _dialogCardSize(WidgetTester tester) {
  // AlertDialog sendiri isi overlay; ukur kad permukaan dalamannya.
  return tester.getSize(
    find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        )
        .first,
  );
}

void main() {
  group('AppDialogShell di Material', () {
    testWidgets('tindakan sebaris: outlined negatif + elevated positif', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TargetPlatform.android,
          (context) => showAppDialog<bool>(
            context,
            title: 'Padam post',
            message: 'Anda pasti?',
            actions: (ctx) => [
              AppDialogAction(
                label: 'Batal',
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              AppDialogAction(
                label: 'Padam',
                isPrimary: true,
                isDestructive: true,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Batal'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Padam'), findsOneWidget);

      // Sebaris = pusat menegak sama, dan lebar sama rata.
      final batal = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Batal'),
      );
      final padam = tester.getRect(
        find.widgetWithText(ElevatedButton, 'Padam'),
      );
      expect(batal.center.dy, moreOrLessEquals(padam.center.dy, epsilon: 0.5));
      expect(batal.width, moreOrLessEquals(padam.width, epsilon: 0.5));
      expect(batal.right, lessThanOrEqualTo(padam.left));
      expect(batal.height, greaterThanOrEqualTo(48));
    });

    testWidgets('dialog dengan medan tak meregang isi skrin', (tester) async {
      _phoneViewport(tester);

      await tester.pumpWidget(
        _host(
          TargetPlatform.android,
          (context) => showAppDialog<void>(
            context,
            title: 'Tambah Bahagian',
            content: const CustomTextField(label: 'Kod', hint: 'BKP'),
            actions: (ctx) => [
              AppDialogAction(
                label: 'Batal',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              AppDialogAction(
                label: 'Tambah',
                isPrimary: true,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(_dialogCardSize(tester).height, lessThan(screen.height * 0.55));
    });

    testWidgets('showEditTextDialog buka form sheet, bukan dialog', (
      tester,
    ) async {
      _phoneViewport(tester);

      await tester.pumpWidget(
        _host(
          TargetPlatform.android,
          (context) => showEditTextDialog(
            context,
            title: 'Edit post',
            initialValue: 'hello',
            maxLines: 5,
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.byType(AppFormSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        tester.getSize(find.byType(AppFormSheet)).height,
        lessThan(screen.height * 0.55),
      );
    });

    testWidgets('showEditTextDialog: Simpan mati bila medan kosong', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TargetPlatform.android,
          (context) => showEditTextDialog(
            context,
            title: 'Nombor Telefon',
            initialValue: '',
            maxLines: 1,
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      final simpan = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Simpan'),
      );
      expect(simpan.onPressed, isNull);

      await tester.enterText(find.byType(TextField), '0123456789');
      await tester.pump();

      final hidup = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Simpan'),
      );
      expect(hidup.onPressed, isNotNull);
    });

    testWidgets('tindakan memusnah guna warna error', (tester) async {
      await tester.pumpWidget(
        _host(
          TargetPlatform.android,
          (context) => showConfirmDialog(
            context,
            title: 'Padam',
            message: 'Pasti?',
            confirmLabel: 'Padam',
            isDestructive: true,
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Padam'),
      );
      final bg = button.style!.backgroundColor!.resolve({});
      expect(bg, AppTheme.light.colorScheme.error);
    });
  });

  testWidgets('AppDialogShell di iOS guna CupertinoAlertDialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TargetPlatform.iOS,
        (context) => showAppDialog<bool>(
          context,
          title: 'Padam post',
          message: 'Anda pasti?',
          actions: (ctx) => [
            AppDialogAction(
              label: 'Batal',
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            AppDialogAction(
              label: 'Padam',
              isPrimary: true,
              isDestructive: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CupertinoDialogAction), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget); // cuma butang 'buka'
  });

  testWidgets('showConfirmDialog pulang false bila barrier ditekan', (
    tester,
  ) async {
    bool? hasil;
    await tester.pumpWidget(
      _host(TargetPlatform.android, (context) async {
        hasil = await showConfirmDialog(
          context,
          title: 'Padam',
          message: 'Pasti?',
        );
      }),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10)); // luar dialog
    await tester.pumpAndSettle();

    expect(hasil, isFalse);
    expect(tester.takeException(), isNull);
  });
}
