import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/members/member_detail_model.dart';
import 'package:marc/features/members/member_detail_page.dart';
import 'package:marc/features/members/member_providers.dart';
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
}
