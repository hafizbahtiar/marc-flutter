import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';
import 'package:marc/shared/ui/dialog/app_dialog_field.dart';
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

void main() {
  group('showAppFormSheet', () {
    testWidgets('tinggi ikut kandungan, bukan isi skrin', (tester) async {
      _phoneViewport(tester);

      await tester.pumpWidget(
        _host(
          TargetPlatform.android,
          (context) => showAppFormSheet<void>(
            context,
            title: 'Tambah Bahagian',
            content: const AppDialogTextField(label: 'Kod', hint: 'BKP'),
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

      expect(find.byType(AppFormSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CupertinoActionSheet), findsNothing);

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        tester.getSize(find.byType(AppFormSheet)).height,
        lessThan(screen.height * 0.55),
      );
    });

    testWidgets('tindakan sebaris: outlined + elevated', (tester) async {
      await tester.pumpWidget(
        _host(
          TargetPlatform.android,
          (context) => showAppFormSheet<void>(
            context,
            title: 'Edit post',
            content: const AppDialogTextField(hint: 'kandungan'),
            actions: (ctx) => [
              AppDialogAction(
                label: 'Batal',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              AppDialogAction(
                label: 'Simpan',
                isPrimary: true,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      final batal = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Batal'),
      );
      final simpan = tester.getRect(
        find.widgetWithText(ElevatedButton, 'Simpan'),
      );
      expect(batal.center.dy, moreOrLessEquals(simpan.center.dy, epsilon: 0.5));
      expect(batal.width, moreOrLessEquals(simpan.width, epsilon: 0.5));
    });

    testWidgets('iOS pun form sheet, bukan action sheet atau alert', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TargetPlatform.iOS,
          (context) => showAppFormSheet<void>(
            context,
            title: 'Sekat Domain',
            content: const AppDialogTextField(label: 'Domain'),
            actions: (ctx) => [
              AppDialogAction(
                label: 'Batal',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.byType(AppFormSheet), findsOneWidget);
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('tutup tanpa sahkan pulang null', (tester) async {
      String? hasil = 'ada';
      await tester.pumpWidget(
        _host(TargetPlatform.android, (context) async {
          hasil = await showAppFormSheet<String>(
            context,
            title: 'Nota',
            content: const AppDialogTextField(hint: 'sebab'),
            actions: (ctx) => [
              AppDialogAction(
                label: 'Batal',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          );
        }),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(hasil, isNull);
    });
  });
}
