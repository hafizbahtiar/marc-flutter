import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/features/profile/settings_page.dart';

Widget _host(Profile viewer) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: '/activities/categories',
        builder: (_, _) => const Scaffold(body: Text('kategori')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [myProfileProvider.overrideWith((ref) async => viewer)],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

Profile _profile({required String roleKey, required int roleRank}) => Profile(
  memberId: 'MARC-0110/2026-0001',
  email: '$roleKey@contoh.com',
  emailVerified: true,
  status: 'approved',
  displayName: roleKey,
  phone: null,
  roleKey: roleKey,
  roleName: roleKey,
  roleRank: roleRank,
  category: roleRank >= 60 ? 'management' : 'ahli',
  telegramLinked: false,
);

void main() {
  testWidgets('admin nampak Urus Kategori di Tetapan', (tester) async {
    await tester.pumpWidget(_host(_profile(roleKey: 'admin', roleRank: 80)));
    await tester.pumpAndSettle();

    expect(find.text('Urus Kategori'), findsOneWidget);
    await tester.tap(find.text('Urus Kategori'));
    await tester.pumpAndSettle();
    expect(find.text('kategori'), findsOneWidget);
  });

  testWidgets('manager tak nampak Urus Kategori', (tester) async {
    await tester.pumpWidget(_host(_profile(roleKey: 'manager', roleRank: 60)));
    await tester.pumpAndSettle();

    expect(find.text('Urus Kategori'), findsNothing);
  });
}
