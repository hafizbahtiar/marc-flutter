import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/members/pending_members_page.dart';
import 'package:marc/features/profile/profile_providers.dart';

Profile _viewer({
  required String roleKey,
  required String roleName,
  required int roleRank,
}) => Profile(
  memberId: 'MARC2026/08/0001',
  email: '$roleKey@contoh.com',
  emailVerified: true,
  status: 'approved',
  displayName: roleName,
  phone: null,
  roleKey: roleKey,
  roleName: roleName,
  roleRank: roleRank,
  category: 'management',
  telegramLinked: false,
);

MemberRow _pending({
  String? staffId = 'EMP-001',
  DateTime? staffIdVerifiedAt,
}) => MemberRow(
  userId: 'user-pending',
  memberId: null,
  displayName: 'Aina',
  email: 'aina@contoh.com',
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: 10,
  category: 'ahli',
  status: 'pending',
  staffId: staffId,
  staffIdVerifiedAt: staffIdVerifiedAt,
);

Widget _host({required Profile viewer, required List<MemberRow> rows}) =>
    ProviderScope(
      overrides: [
        myProfileProvider.overrideWith((ref) async => viewer),
        pendingMembersProvider.overrideWith((ref) async => rows),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const PendingMembersPage(),
      ),
    );

void main() {
  testWidgets('papar nombor staff dan butang sahkan untuk manager', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        viewer: _viewer(roleKey: 'manager', roleName: 'Manager', roleRank: 60),
        rows: [_pending()],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Nombor staff: EMP-001'), findsOneWidget);
    expect(find.text('Sahkan Nombor Staff'), findsOneWidget);
  });

  testWidgets('supervisor tak nampak butang sahkan', (tester) async {
    await tester.pumpWidget(
      _host(
        viewer: _viewer(
          roleKey: 'supervisor',
          roleName: 'Supervisor',
          roleRank: 40,
        ),
        rows: [_pending()],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Nombor staff: EMP-001'), findsOneWidget);
    expect(find.text('Sahkan Nombor Staff'), findsNothing);
  });

  testWidgets('Luluskan dimatikan sehingga nombor staff disahkan', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        viewer: _viewer(roleKey: 'manager', roleName: 'Manager', roleRank: 60),
        rows: [_pending()],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aina'));
    await tester.pumpAndSettle();

    expect(find.text('Sahkan nombor staff dulu'), findsOneWidget);
    final luluskan = tester.widget<ListTile>(
      find
          .ancestor(of: find.text('Luluskan'), matching: find.byType(ListTile))
          .first,
    );
    expect(luluskan.enabled, isFalse);
  });

  testWidgets('Luluskan aktif selepas nombor staff disahkan', (tester) async {
    await tester.pumpWidget(
      _host(
        viewer: _viewer(roleKey: 'manager', roleName: 'Manager', roleRank: 60),
        rows: [_pending(staffIdVerifiedAt: DateTime(2026, 9, 2))],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sahkan Nombor Staff'), findsNothing);

    await tester.tap(find.text('Aina'));
    await tester.pumpAndSettle();

    expect(find.text('Nombor staff telah disahkan'), findsOneWidget);
    final luluskan = tester.widget<ListTile>(
      find
          .ancestor(of: find.text('Luluskan'), matching: find.byType(ListTile))
          .first,
    );
    expect(luluskan.enabled, isTrue);
  });
}
