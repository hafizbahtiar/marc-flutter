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
  Object? displayName = _useDefaultName,
  String? departmentCode,
  String? departmentName,
}) => MemberRow(
  userId: userId,
  memberId: memberId,
  displayName: identical(displayName, _useDefaultName)
      ? 'Ahli $memberId'
      : displayName as String?,
  email: null,
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: roleRank,
  category: 'ahli',
  status: 'approved',
  departmentCode: departmentCode,
  departmentName: departmentName,
);

/// Sentinel - bezakan "displayName tak dinyatakan" (guna lalai `Ahli
/// $memberId`) drpd "displayName sengaja null" (ahli tanpa nama, carian
/// mesti tetap padan drpd `memberId`).
const _useDefaultName = Object();

/// Router ujian minimal - `_MemberTile.onTap` guna `context.push`, jadi
/// perlu `GoRouter` sebenar dalam pokok widget (bukan `MaterialApp` biasa,
/// yang akan lontar ralat "No GoRouter found"). Laluan `/members` padan
/// pola router sebenar (`state.extra as String?` -> `initialDepartmentCode`)
/// supaya ujian navigasi chip bahagian (`member_detail_page_test.dart`
/// punya pasangan) sah terhadap mekanisme sebenar.
Widget _host({
  required Profile viewer,
  required List<MemberRow> rows,
  String initialLocation = '/members',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/members',
        builder: (_, state) =>
            MembersPage(initialDepartmentCode: state.extra as String?),
      ),
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

const _viewer = Profile(
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

  testWidgets(
    'carian padan nama (case-insensitive), dan ahli tanpa nama tetap padan drpd no. ahli',
    (tester) async {
      final aina = _row(
        userId: 'user-aina',
        memberId: 'MARC2026/08/0010',
        roleRank: 10,
        displayName: 'Aina Zulaikha',
      );
      final busu = _row(
        userId: 'user-busu',
        memberId: 'MARC2026/08/0011',
        roleRank: 10,
        displayName: 'Busu Rahman',
      );
      final noName = _row(
        userId: 'user-noname',
        memberId: 'MARC2026/08/0099',
        roleRank: 10,
        displayName: null,
      );

      await tester.pumpWidget(
        _host(viewer: _viewer, rows: [aina, busu, noName]),
      );
      await tester.pumpAndSettle();

      // Semua tiga ahli papar mula-mula (tiada penapis).
      expect(find.text('Aina Zulaikha'), findsOneWidget);
      expect(find.text('Busu Rahman'), findsOneWidget);
      expect(find.text('(Tiada nama)'), findsOneWidget);

      // Carian huruf besar sepadan nama huruf kecil - case-insensitive.
      await tester.enterText(find.byType(TextField), 'AINA');
      await tester.pumpAndSettle();

      expect(find.text('Aina Zulaikha'), findsOneWidget);
      expect(find.text('Busu Rahman'), findsNothing);
      expect(find.text('(Tiada nama)'), findsNothing);

      // Carian drpd no. ahli - mesti padan ahli yang tiada displayName.
      await tester.enterText(find.byType(TextField), '0099');
      await tester.pumpAndSettle();

      expect(find.text('(Tiada nama)'), findsOneWidget);
      expect(find.text('Aina Zulaikha'), findsNothing);
      expect(find.text('Busu Rahman'), findsNothing);

      // Carian tiada padanan - keadaan kosong khusus, bukan senarai kosong
      // biasa ("Tiada ahli.").
      await tester.enterText(find.byType(TextField), 'zzzzz');
      await tester.pumpAndSettle();

      expect(find.text('Tiada ahli sepadan.'), findsOneWidget);
    },
  );

  testWidgets(
    'penapis bahagian (chip) sempitkan senarai kepada satu bahagian',
    (tester) async {
      final bkp = _row(
        userId: 'user-bkp',
        memberId: 'MARC2026/08/0020',
        roleRank: 10,
        displayName: 'Ahli BKP',
        departmentCode: 'BKP',
        departmentName: 'Bahagian Kewangan & Pentadbiran',
      );
      final bpk = _row(
        userId: 'user-bpk',
        memberId: 'MARC2026/08/0021',
        roleRank: 10,
        displayName: 'Ahli BPK',
        departmentCode: 'BPK',
        departmentName: 'Bahagian Pembangunan Komuniti',
      );
      final noDept = _row(
        userId: 'user-nodept',
        memberId: 'MARC2026/08/0022',
        roleRank: 10,
        displayName: 'Ahli Tanpa Bahagian',
      );

      await tester.pumpWidget(_host(viewer: _viewer, rows: [bkp, bpk, noDept]));
      await tester.pumpAndSettle();

      // Semua tiga papar bila "Semua" dipilih (lalai).
      expect(find.text('Ahli BKP'), findsOneWidget);
      expect(find.text('Ahli BPK'), findsOneWidget);
      expect(find.text('Ahli Tanpa Bahagian'), findsOneWidget);

      await tester.tap(find.text('Bahagian Kewangan & Pentadbiran'));
      await tester.pumpAndSettle();

      expect(find.text('Ahli BKP'), findsOneWidget);
      expect(find.text('Ahli BPK'), findsNothing);
      expect(find.text('Ahli Tanpa Bahagian'), findsNothing);

      // "Semua" kembalikan senarai penuh.
      await tester.tap(find.text('Semua'));
      await tester.pumpAndSettle();

      expect(find.text('Ahli BKP'), findsOneWidget);
      expect(find.text('Ahli BPK'), findsOneWidget);
      expect(find.text('Ahli Tanpa Bahagian'), findsOneWidget);
    },
  );

  testWidgets('carian + penapis bahagian gabung dgn logik DAN', (tester) async {
    final ainaBkp = _row(
      userId: 'user-aina-bkp',
      memberId: 'MARC2026/08/0030',
      roleRank: 10,
      displayName: 'Aina (BKP)',
      departmentCode: 'BKP',
      departmentName: 'Bahagian Kewangan',
    );
    final busuBkp = _row(
      userId: 'user-busu-bkp',
      memberId: 'MARC2026/08/0031',
      roleRank: 10,
      displayName: 'Busu (BKP)',
      departmentCode: 'BKP',
      departmentName: 'Bahagian Kewangan',
    );
    final ainaBpk = _row(
      userId: 'user-aina-bpk',
      memberId: 'MARC2026/08/0032',
      roleRank: 10,
      displayName: 'Aina (BPK)',
      departmentCode: 'BPK',
      departmentName: 'Bahagian Pembangunan',
    );

    await tester.pumpWidget(
      _host(viewer: _viewer, rows: [ainaBkp, busuBkp, ainaBpk]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bahagian Kewangan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'aina');
    await tester.pumpAndSettle();

    // Cuma "Aina (BKP)" padan DUA-DUA penapis (bahagian BKP + nama Aina).
    expect(find.text('Aina (BKP)'), findsOneWidget);
    expect(find.text('Busu (BKP)'), findsNothing);
    expect(find.text('Aina (BPK)'), findsNothing);
  });

  testWidgets(
    'initialDepartmentCode (drpd extra chip di skrin profil) pra-terap penapis & papar chip terpilih',
    (tester) async {
      final bkp = _row(
        userId: 'user-bkp',
        memberId: 'MARC2026/08/0040',
        roleRank: 10,
        displayName: 'Ahli BKP',
        departmentCode: 'BKP',
        departmentName: 'Bahagian Kewangan',
      );
      final bpk = _row(
        userId: 'user-bpk',
        memberId: 'MARC2026/08/0041',
        roleRank: 10,
        displayName: 'Ahli BPK',
        departmentCode: 'BPK',
        departmentName: 'Bahagian Pembangunan',
      );

      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
          ),
          GoRoute(
            path: '/members',
            builder: (_, state) =>
                MembersPage(initialDepartmentCode: state.extra as String?),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myProfileProvider.overrideWith((ref) async => _viewer),
            membersProvider.overrideWith((ref) async => [bkp, bpk]),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.push('/members', extra: 'BKP');
      await tester.pumpAndSettle();

      // Direktori terus papar tertapis - BUKAN senyap: chip "Bahagian
      // Kewangan" kelihatan terpilih dan BPK tak dipapar.
      expect(find.text('Ahli BKP'), findsOneWidget);
      expect(find.text('Ahli BPK'), findsNothing);

      final choiceChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Bahagian Kewangan'),
      );
      expect(choiceChip.selected, isTrue);
    },
  );
}
