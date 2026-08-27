import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';
import 'package:marc/shared/ui/dialog/confirm_dialog.dart';

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
