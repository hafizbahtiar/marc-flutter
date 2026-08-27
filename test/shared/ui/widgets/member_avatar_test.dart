import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/media/app_network_image.dart';
import 'package:marc/shared/ui/widgets/member_avatar.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('fallback bila tiada gambar', () {
    testWidgets('papar huruf pertama, tiada muat turun rangkaian', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const MemberAvatar(label: 'Hafiz')));
      await tester.pump();

      expect(find.text('H'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsNothing);
    });

    testWidgets('nama kosong jadi "?" dan bukan ranap', (tester) async {
      await tester.pumpWidget(_host(const MemberAvatar(label: '   ')));
      await tester.pump();

      expect(find.text('?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('huruf dibesarkan', (tester) async {
      await tester.pumpWidget(_host(const MemberAvatar(label: 'ali')));
      await tester.pump();
      expect(find.text('A'), findsOneWidget);
    });
  });

  testWidgets('guna AppNetworkImage bila ada URL (cache + had nyahkod)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const MemberAvatar(
          label: 'Hafiz',
          avatarUrl: 'https://pub-test.r2.dev/posts/a.jpg',
        ),
      ),
    );
    await tester.pump();

    // Image.network mentah akan menyahkod pada resolusi penuh; avatar
    // dipapar dalam bulatan kecil, jadi laluan yang dihadkan itu penting.
    expect(find.byType(AppNetworkImage), findsOneWidget);
    expect(find.text('H'), findsNothing);
  });

  // radius memandu saiz lukisan DAN lebar nyahkod - avatar comment (14)
  // lwn header profil (30) berbeza lebih empat kali ganda dlm luas piksel.
  testWidgets('radius menentukan diameter yang dilukis', (tester) async {
    for (final radius in [14.0, 30.0]) {
      await tester.pumpWidget(_host(MemberAvatar(label: 'A', radius: radius)));
      await tester.pump();
      final size = tester.getSize(find.byType(MemberAvatar));
      expect(size.width, radius * 2);
      expect(size.height, radius * 2);
    }
  });

  testWidgets('boleh diketuk hanya bila onTap diberi', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(MemberAvatar(label: 'A', onTap: () => taps++)),
    );
    await tester.pump();

    await tester.tap(find.byType(MemberAvatar));
    await tester.pump();
    expect(taps, 1);

    await tester.pumpWidget(_host(const MemberAvatar(label: 'A')));
    await tester.pump();
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('ada label semantik untuk pembaca skrin', (tester) async {
    await tester.pumpWidget(_host(const MemberAvatar(label: 'Hafiz')));
    await tester.pump();

    expect(
      tester.getSemantics(find.byType(MemberAvatar)).label,
      contains('Hafiz'),
    );
  });
}
