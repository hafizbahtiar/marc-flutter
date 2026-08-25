import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/members/members_page.dart';
import 'package:marc/features/profile/profile_providers.dart';

MemberRow _row({
  required String userId,
  required String memberId,
  required int roleRank,
}) => MemberRow(
  userId: userId,
  memberId: memberId,
  displayName: 'Ahli $memberId',
  email: null,
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: roleRank,
  category: 'ahli',
  status: 'approved',
);

/// Router ujian minimal - `_MemberTile.onTap` guna `context.push`, jadi
/// perlu `GoRouter` sebenar dalam pokok widget (bukan `MaterialApp` biasa,
/// yang akan lontar ralat "No GoRouter found").
Widget _host({required Profile viewer, required List<MemberRow> rows}) {
  final router = GoRouter(
    initialLocation: '/members',
    routes: [
      GoRoute(path: '/members', builder: (_, _) => const MembersPage()),
      GoRoute(
        path: '/members/:userId',
        builder: (_, state) =>
            Scaffold(body: Text('detail-${state.pathParameters['userId']}')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      myProfileProvider.overrideWith((ref) async => viewer),
      membersProvider.overrideWith((ref) async => rows),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  // Regresi: sebelum ni `_MemberTile.onTap` cuma buka sheet tindakan
  // pengurusan bila `canEdit`/`canEditDeptPosition` - ahli biasa yang
  // ketuk baris ahli lain (rank sama/lebih tinggi) tak buat apa-apa
  // langsung. Skrin profil view-only baru ni patut boleh dicapai oleh
  // SEMUA viewer, tanpa kira kebenaran edit.
  testWidgets(
    'viewer TANPA kebenaran edit (rank rendah) tetap navigasi ke profil ahli',
    (tester) async {
      const viewer = Profile(
        memberId: 'MARC2026/08/0001',
        email: 'a@b.com',
        emailVerified: true,
        status: 'approved',
        displayName: 'Viewer',
        phone: null,
        roleKey: 'ahli',
        roleName: 'Ahli',
        roleRank: 10,
        category: 'ahli',
        telegramLinked: false,
      );
      final target = _row(
        userId: 'user-target',
        memberId: 'MARC2026/08/0002',
        roleRank: 90,
      );

      await tester.pumpWidget(_host(viewer: viewer, rows: [target]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ahli MARC2026/08/0002'));
      await tester.pumpAndSettle();

      expect(find.text('detail-user-target'), findsOneWidget);
    },
  );

  testWidgets(
    'viewer DENGAN kebenaran edit (rank tinggi) juga navigasi ke profil (bukan sheet)',
    (tester) async {
      const viewer = Profile(
        memberId: 'MARC2026/08/0001',
        email: 'a@b.com',
        emailVerified: true,
        status: 'approved',
        displayName: 'Viewer',
        phone: null,
        roleKey: 'superadmin',
        roleName: 'Super Admin',
        roleRank: 100,
        category: 'management',
        telegramLinked: false,
      );
      final target = _row(
        userId: 'user-target-2',
        memberId: 'MARC2026/08/0003',
        roleRank: 10,
      );

      await tester.pumpWidget(_host(viewer: viewer, rows: [target]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ahli MARC2026/08/0003'));
      await tester.pumpAndSettle();

      expect(find.text('detail-user-target-2'), findsOneWidget);
      // Tiada sheet tindakan pengurusan dicetus dari sini lagi.
      expect(find.text('Tukar role'), findsNothing);
    },
  );
}
