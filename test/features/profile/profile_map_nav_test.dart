import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/profile/profile_page.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/ui/map/map_page.dart';

class _LoggedInAuth extends AuthNotifier {
  _LoggedInAuth() : super(TokenStorage()) {
    state = const AuthState(isLoggedIn: true, accessToken: 'a');
  }
}

const _profile = Profile(
  memberId: 'MARC2026/08/0001',
  email: 'a@b.com',
  emailVerified: true,
  status: 'approved',
  displayName: 'Hafiz',
  phone: null,
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: 10,
  category: 'ahli',
  telegramLinked: false,
);

Widget _host() {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
      GoRoute(path: '/map', builder: (_, _) => const MapPage()),
    ],
  );

  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith((ref) => _LoggedInAuth()),
      myProfileProvider.overrideWith((ref) async => _profile),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  testWidgets('Profil ada pintasan ujian ke halaman peta', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('Peta (ujian)'), findsOneWidget);

    await tester.ensureVisible(find.text('Peta (ujian)'));
    await tester.tap(find.text('Peta (ujian)'));
    // Satu `pump` cuma mula transisi go_router; tunggu animasi siap
    // tanpa `pumpAndSettle` (fade jubin peta boleh tak pernah settle).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MapPage), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
  });
}
