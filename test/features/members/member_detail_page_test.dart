import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/members/member_detail_model.dart';
import 'package:marc/features/members/member_detail_page.dart';
import 'package:marc/features/members/member_providers.dart';
import 'package:marc/features/members/members_page.dart';
import 'package:marc/features/profile/address_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';

const _viewerProfile = Profile(
  memberId: 'MARC2026/08/0001',
  email: 'viewer@contoh.com',
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

MemberDetail _standardTier() => const MemberDetail(
  userId: 'user-1',
  memberId: 'MARC2026/08/0002',
  displayName: 'Aina',
  avatarUrl: null,
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: 10,
  category: 'ahli',
  status: 'approved',
  isActive: true,
  departmentCode: null,
  departmentName: null,
  position: null,
  email: null,
  phone: null,
  registrationPaymentStatus: null,
  emergencyContactName: null,
  emergencyContactPhone: null,
  healthNotes: null,
  telegramLinked: null,
  telegramUsername: null,
  addresses: null,
);

MemberDetail _adminTier() => _standardTier2Copy(
  email: 'aina@contoh.com',
  phone: '0123456789',
  registrationPaymentStatus: 'succeeded',
);

MemberDetail _standardTier2Copy({
  String? email,
  String? phone,
  String? registrationPaymentStatus,
}) => MemberDetail(
  userId: 'user-1',
  memberId: 'MARC2026/08/0002',
  displayName: 'Aina',
  avatarUrl: null,
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: 10,
  category: 'ahli',
  status: 'approved',
  isActive: true,
  departmentCode: null,
  departmentName: null,
  position: null,
  email: email,
  phone: phone,
  registrationPaymentStatus: registrationPaymentStatus,
  emergencyContactName: null,
  emergencyContactPhone: null,
  healthNotes: null,
  telegramLinked: null,
  telegramUsername: null,
  addresses: null,
);

MemberDetail _superAdminTier({required List<AddressRow>? addresses}) =>
    MemberDetail(
      userId: 'user-1',
      memberId: 'MARC2026/08/0002',
      displayName: 'Aina',
      avatarUrl: null,
      roleKey: 'ahli',
      roleName: 'Ahli',
      roleRank: 10,
      category: 'ahli',
      status: 'approved',
      isActive: true,
      departmentCode: null,
      departmentName: null,
      position: null,
      email: 'aina@contoh.com',
      phone: '0123456789',
      registrationPaymentStatus: 'succeeded',
      emergencyContactName: 'Ali',
      emergencyContactPhone: '0198765432',
      healthNotes: 'Asma',
      telegramLinked: true,
      telegramUsername: 'aina_tg',
      addresses: addresses,
    );

AddressRow _address({String id = 'addr-1'}) => AddressRow(
  id: id,
  label: 'Rumah',
  isDefault: true,
  addressType: 'landed',
  unitNumber: 'No. 12',
  street: 'Jalan Contoh 1',
  township: 'Taman Contoh',
  city: 'Shah Alam',
  postcode: '40000',
  state: 'Selangor',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Widget _host(MemberDetail detail) => ProviderScope(
  overrides: [
    myProfileProvider.overrideWith((ref) async => _viewerProfile),
    memberDetailProvider.overrideWith((ref, userId) async => detail),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const MemberDetailPage(userId: 'user-1'),
  ),
);

void main() {
  testWidgets('tier standard - seksyen Kenalan/Kecemasan/Alamat tak wujud', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_standardTier()));
    await tester.pumpAndSettle();

    expect(find.text('Aina'), findsOneWidget);
    expect(find.text('Kenalan'), findsNothing);
    expect(find.text('Kecemasan & Kesihatan'), findsNothing);
    expect(find.text('Alamat'), findsNothing);
  });

  testWidgets('tier admin - Kenalan wujud, Kecemasan/Alamat tak wujud', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_adminTier()));
    await tester.pumpAndSettle();

    expect(find.text('Kenalan'), findsOneWidget);
    expect(find.text('aina@contoh.com'), findsOneWidget);
    expect(find.text('0123456789'), findsOneWidget);
    expect(find.text('Kecemasan & Kesihatan'), findsNothing);
    expect(find.text('Alamat'), findsNothing);
  });

  testWidgets(
    'tier superadmin dengan senarai alamat tak kosong - semua seksyen wujud',
    (tester) async {
      // Skrin ni panjang (header + tiga seksyen) - viewport ujian lalai
      // (~800 logik) memotong seksyen bawah di luar cache extent
      // ListView (elemen offscreen tak dibina, jadi find.text gagal
      // walaupun data betul). Besarkan viewport supaya semua kandungan
      // muat tanpa perlu scroll manual, padanan pola
      // `app_action_sheet_test.dart`.
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(_superAdminTier(addresses: [_address()])));
      await tester.pumpAndSettle();

      expect(find.text('Kenalan'), findsOneWidget);
      expect(find.text('Kecemasan & Kesihatan'), findsOneWidget);
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('0198765432'), findsOneWidget);
      expect(find.text('Asma'), findsOneWidget);
      expect(find.text('Alamat'), findsOneWidget);
      expect(find.text('Rumah'), findsOneWidget);
      expect(find.text('Tiada alamat.'), findsNothing);
    },
  );

  testWidgets(
    'tier superadmin dengan senarai alamat KOSONG - seksyen Alamat wujud tapi papar keadaan kosong (BUKAN tersembunyi)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(_superAdminTier(addresses: const [])));
      await tester.pumpAndSettle();

      expect(find.text('Alamat'), findsOneWidget);
      expect(find.text('Tiada alamat.'), findsOneWidget);
    },
  );

  testWidgets(
    'ketuk chip bahagian navigasi ke direktori ahli (/members) tertapis kpd bahagian tu',
    (tester) async {
      final detail = MemberDetail(
        userId: 'user-1',
        memberId: 'MARC2026/08/0002',
        displayName: 'Aina',
        avatarUrl: null,
        roleKey: 'ahli',
        roleName: 'Ahli',
        roleRank: 10,
        category: 'ahli',
        status: 'approved',
        isActive: true,
        departmentCode: 'BKP',
        departmentName: 'Bahagian Kewangan',
        position: 'Setiausaha',
        email: null,
        phone: null,
        registrationPaymentStatus: null,
        emergencyContactName: null,
        emergencyContactPhone: null,
        healthNotes: null,
        telegramLinked: null,
        telegramUsername: null,
        addresses: null,
      );
      final sameDept = MemberRow(
        userId: 'user-1',
        memberId: 'MARC2026/08/0002',
        displayName: 'Aina',
        email: null,
        roleKey: 'ahli',
        roleName: 'Ahli',
        roleRank: 10,
        category: 'ahli',
        status: 'approved',
        departmentCode: 'BKP',
        departmentName: 'Bahagian Kewangan',
      );
      final otherDept = MemberRow(
        userId: 'user-2',
        memberId: 'MARC2026/08/0003',
        displayName: 'Busu',
        email: null,
        roleKey: 'ahli',
        roleName: 'Ahli',
        roleRank: 10,
        category: 'ahli',
        status: 'approved',
        departmentCode: 'BPK',
        departmentName: 'Bahagian Pembangunan',
      );

      // Router sebenar - laluan `/members` padan pola `router.dart` (baca
      // `state.extra` sbg `initialDepartmentCode`), supaya ujian ni
      // mengesahkan mekanisme navigasi sebenar, bukan stub.
      final router = GoRouter(
        initialLocation: '/members/user-1',
        routes: [
          GoRoute(
            path: '/members/:userId',
            builder: (_, state) =>
                MemberDetailPage(userId: state.pathParameters['userId']!),
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
            myProfileProvider.overrideWith((ref) async => _viewerProfile),
            memberDetailProvider.overrideWith((ref, userId) async => detail),
            membersProvider.overrideWith((ref) async => [sameDept, otherDept]),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "BKP · Setiausaha" - chip gabungan kod bahagian + jawatan.
      await tester.tap(find.text('BKP · Setiausaha'));
      await tester.pumpAndSettle();

      // Direktori ahli terpapar (AppBar 'Ahli', beza drpd 'Profil Ahli'
      // skrin profil), tertapis kepada BKP sahaja - Busu (BPK) TIDAK
      // dipapar walaupun ada dlm senarai penuh. (Tak semak "Aina"
      // findsOneWidget di sini - skrin profil sebelum ni kekal dlm pokok
      // widget di bawah `Navigator`/`Overlay`, jadi teksnya turut kekal
      // "onstage" mengikut `find.text`, bukan cuma satu kew wujudan.)
      expect(find.widgetWithText(AppBar, 'Ahli'), findsOneWidget);
      expect(find.text('Busu'), findsNothing);
    },
  );
}
