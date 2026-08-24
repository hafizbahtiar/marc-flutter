import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/profile/profile_page.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/member_avatar.dart';

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

Widget _host(Profile? profile) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith((ref) => _LoggedInAuth()),
    myProfileProvider.overrideWith((ref) async => profile),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const ProfilePage()),
);

/// Regresi: avatar header pernah dirender TANPA `onTap` sama sekali -
/// `onTapAvatar` dihantar ke `_Header` tapi tak pernah disambung ke
/// `MemberAvatar`. Ketuk gambar profil tak buat apa-apa, dan
/// `flutter analyze` senyap sebab medan instance yang tak diguna bukan
/// amaran. Ujian ni periksa PENYAMBUNGAN, bukan sekadar widget wujud.
void main() {
  testWidgets('avatar profil boleh diketuk bila profil dah dimuat', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_profile));
    await tester.pumpAndSettle();

    final avatar = tester.widget<MemberAvatar>(find.byType(MemberAvatar).first);
    expect(
      avatar.onTap,
      isNotNull,
      reason: 'ketuk gambar profil takkan buat apa-apa',
    );
  });

  testWidgets('lencana kamera dipapar sebagai affordance', (tester) async {
    await tester.pumpWidget(_host(_profile));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
  });

  // Tiada profil = tiada apa untuk dikemas kini; avatar tak patut boleh
  // diketuk dan lencana tak patut menjanjikan sesuatu yang tak berfungsi.
  testWidgets('tiada tap/lencana bila profil belum ada', (tester) async {
    await tester.pumpWidget(_host(null));
    await tester.pumpAndSettle();

    final avatar = tester.widget<MemberAvatar>(find.byType(MemberAvatar).first);
    expect(avatar.onTap, isNull);
    expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
  });
}
