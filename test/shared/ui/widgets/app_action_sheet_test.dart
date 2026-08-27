import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/sheet/app_action_sheet.dart';

enum _Action { edit, delete }

const _actions = [
  AppSheetAction(value: _Action.edit, label: 'Edit', icon: Icons.edit_outlined),
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
  group('AppActionSheetMetrics', () {
    const screen = 780.0;

    test('sedikit item → compact, tinggi ikut kandungan', () {
      final e = AppActionSheetMetrics.layout(
        actionCount: 2,
        hasHeader: true,
        hasSubtitle: false,
        screenHeight: screen,
        bottomInset: 0,
      );
      expect(e.compact, isTrue);
      expect(e.initial, e.max);
      expect(e.initial, lessThan(AppActionSheetMetrics.defaultInitial));
      expect(e.initial, greaterThan(0));
    });

    test('lebih sikit dari default → initial ikut item, bukan default', () {
      // 7 jubin: melepasi 50% sikit, masih dalam slack 2 jubin.
      final e = AppActionSheetMetrics.layout(
        actionCount: 7,
        hasHeader: true,
        hasSubtitle: false,
        screenHeight: screen,
        bottomInset: 0,
      );
      expect(e.compact, isFalse);
      expect(e.initial, greaterThan(AppActionSheetMetrics.defaultInitial));
      expect(e.initial, lessThanOrEqualTo(AppActionSheetMetrics.maxSize));
      expect(e.max, AppActionSheetMetrics.maxSize);
    });

    test('banyak item → initial default, boleh dileret ke max', () {
      final e = AppActionSheetMetrics.layout(
        actionCount: 20,
        hasHeader: true,
        hasSubtitle: false,
        screenHeight: screen,
        bottomInset: 0,
      );
      expect(e.compact, isFalse);
      expect(e.initial, AppActionSheetMetrics.defaultInitial);
      expect(e.max, AppActionSheetMetrics.maxSize);
      expect(e.min, lessThan(e.initial));
    });
  });

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
        (context) => showAppActionSheet<_Action>(context, actions: _actions),
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
        dipilih = await showAppActionSheet<_Action>(context, actions: _actions);
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

  testWidgets('Material: senarai panjang tak overflow dan boleh di-scroll', (
    tester,
  ) async {
    // Padanan peranti overflow sebenar (~360x780 logik, sheet ~separuh).
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final actions = [
      for (var i = 0; i < 20; i++)
        AppSheetAction(value: i, label: 'Kategori $i'),
    ];
    await tester.pumpWidget(
      _host(
        TargetPlatform.android,
        (context) => showAppActionSheet<int>(
          context,
          title: 'Pilih kategori',
          actions: actions,
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Kategori 0'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Kategori 19'), 300);
    expect(find.text('Kategori 19'), findsOneWidget);
  });

  testWidgets('Sheet kekal boleh dibaca dalam mod gelap', (tester) async {
    await tester.pumpWidget(
      _host(
        TargetPlatform.android,
        (context) => showAppActionSheet<_Action>(context, actions: _actions),
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
