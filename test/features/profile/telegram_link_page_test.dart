import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/features/profile/telegram_link_page.dart';

const _profileBelumTerikat = Profile(
  memberId: 'MARC/2026/01/0001',
  email: 'ujian@test.local',
  emailVerified: true,
  status: 'approved',
  displayName: null,
  phone: null,
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: 0,
  category: 'ahli',
  telegramLinked: false,
);

const _profileTerikat = Profile(
  memberId: 'MARC/2026/01/0002',
  email: 'ujian2@test.local',
  emailVerified: true,
  status: 'approved',
  displayName: null,
  phone: null,
  roleKey: 'ahli',
  roleName: 'Ahli',
  roleRank: 0,
  category: 'ahli',
  telegramLinked: true,
  telegramUsername: 'ahliuji',
);

Widget _wrap(Profile profile) => ProviderScope(
  overrides: [myProfileProvider.overrideWith((ref) async => profile)],
  child: MaterialApp(theme: AppTheme.light, home: const TelegramLinkPage()),
);

void main() {
  testWidgets('papar butang Sambung bila belum terikat', (tester) async {
    await tester.pumpWidget(_wrap(_profileBelumTerikat));
    await tester.pumpAndSettle();

    expect(find.text('Sambung Telegram'), findsOneWidget);
    expect(find.text('Nyahikat'), findsNothing);
  });

  testWidgets('papar keadaan Disambungkan + username bila terikat', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_profileTerikat));
    await tester.pumpAndSettle();

    expect(find.text('Nyahikat'), findsOneWidget);
    expect(find.textContaining('@ahliuji'), findsOneWidget);
  });
}
