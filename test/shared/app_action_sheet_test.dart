import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/widgets/app_action_sheet.dart';

enum _Action { edit, delete }

const _actions = [
  AppSheetAction(
    value: _Action.edit,
    label: 'Edit',
    icon: Icons.edit_outlined,
  ),
  AppSheetAction(
    value: _Action.delete,
    label: 'Padam',
    icon: Icons.delete_outline,
    isDestructive: true,
  ),
];

Widget _host(
  TargetPlatform platform,
  void Function(BuildContext) onTap, {
  ThemeMode mode = ThemeMode.light,
}) {
  return MaterialApp(
    theme: AppTheme.light.copyWith(platform: platform),
    darkTheme: AppTheme.dark.copyWith(platform: platform),
    themeMode: mode,
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
  testWidgets('Material: pilih tindakan pulang value-nya', (tester) async {
    _Action? dipilih;
    await tester.pumpWidget(
      _host(TargetPlatform.android, (context) async {
        dipilih = await showAppActionSheet<_Action>(
          context,
          title: 'Comment Hafiz',
          actions: _actions,
        );
      }),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Comment Hafiz'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Padam'), findsOneWidget);

    await tester.tap(find.text('Padam'));
    await tester.pumpAndSettle();

    expect(dipilih, _Action.delete);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Material: tindakan memusnah guna warna error', (tester) async {
    await tester.pumpWidget(
      _host(
        TargetPlatform.android,
        (context) =>
            showAppActionSheet<_Action>(context, actions: _actions),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    final padam = tester.widget<Text>(find.text('Padam'));
    final edit = tester.widget<Text>(find.text('Edit'));
    final scheme = AppTheme.light.colorScheme;
    expect(padam.style?.color, scheme.error);
    expect(edit.style?.color, scheme.onSurface);
  });

  testWidgets('Material: tutup tanpa pilih pulang null', (tester) async {
    _Action? dipilih = _Action.edit;
    await tester.pumpWidget(
      _host(TargetPlatform.android, (context) async {
        dipilih = await showAppActionSheet<_Action>(
          context,
          actions: _actions,
        );
      }),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10)); // scrim
    await tester.pumpAndSettle();

    expect(dipilih, isNull);
  });

  testWidgets('Material: isSelected papar tanda semak', (tester) async {
    await tester.pumpWidget(
      _host(
        TargetPlatform.android,
        (context) => showAppActionSheet<String>(
          context,
          title: 'Tukar role',
          actions: const [
            AppSheetAction(value: 'ahli', label: 'Ahli', isSelected: true),
            AppSheetAction(value: 'supervisor', label: 'Supervisor'),
          ],
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('iOS: guna CupertinoActionSheet dengan butang Batal', (
    tester,
  ) async {
    _Action? dipilih;
    await tester.pumpWidget(
      _host(TargetPlatform.iOS, (context) async {
        dipilih = await showAppActionSheet<_Action>(
          context,
          title: 'Post',
          actions: _actions,
        );
      }),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(dipilih, _Action.edit);
  });

  testWidgets('Sheet kekal boleh dibaca dalam mod gelap', (tester) async {
    await tester.pumpWidget(
      _host(
        TargetPlatform.android,
        (context) =>
            showAppActionSheet<_Action>(context, actions: _actions),
        mode: ThemeMode.dark,
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    final edit = tester.widget<Text>(find.text('Edit'));
    expect(edit.style?.color, AppTheme.dark.colorScheme.onSurface);
    expect(tester.takeException(), isNull);
  });
}
