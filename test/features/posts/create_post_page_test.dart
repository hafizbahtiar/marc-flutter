import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/posts/create_post_page.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/member_avatar.dart';

Profile _profile({required bool management}) => Profile(
  memberId: 'MARC2026/08/0001',
  email: 'a@b.com',
  emailVerified: true,
  status: 'approved',
  displayName: 'Hafiz',
  phone: null,
  roleKey: management ? 'manager' : 'ahli',
  roleName: management ? 'Manager' : 'Ahli',
  roleRank: management ? 60 : 10,
  category: management ? 'management' : 'ahli',
  telegramLinked: false,
);

Widget _host({required bool management}) => ProviderScope(
  overrides: [
    myProfileProvider.overrideWith(
      (ref) async => _profile(management: management),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const CreatePostPage()),
);

FilledButton _sendButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Hantar'));

void main() {
  group('butang hantar', () {
    // Dulu penggubah menerima ketukan pada penggubah kosong dan membalas
    // dengan snackbar ralat. Butang mati menyatakan perkara sama sebelum
    // pengguna cuba.
    testWidgets('mati bila tiada teks dan tiada gambar', (tester) async {
      await tester.pumpWidget(_host(management: false));
      await tester.pumpAndSettle();

      expect(_sendButton(tester).onPressed, isNull);
    });

    testWidgets('hidup sebaik ada teks', (tester) async {
      await tester.pumpWidget(_host(management: false));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Assalamualaikum semua');
      await tester.pump();

      expect(_sendButton(tester).onPressed, isNotNull);
    });

    testWidgets('kekal mati untuk ruang kosong sahaja', (tester) async {
      await tester.pumpWidget(_host(management: false));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '     ');
      await tester.pump();

      expect(_sendButton(tester).onPressed, isNull);
    });
  });

  group('pil pengumuman', () {
    testWidgets('tersembunyi untuk ahli biasa', (tester) async {
      await tester.pumpWidget(_host(management: false));
      await tester.pumpAndSettle();

      expect(find.text('Post biasa'), findsNothing);
      expect(find.text('Pengumuman'), findsNothing);
    });

    testWidgets('management nampak, dan boleh toggle', (tester) async {
      await tester.pumpWidget(_host(management: true));
      await tester.pumpAndSettle();

      expect(find.text('Post biasa'), findsOneWidget);

      await tester.tap(find.text('Post biasa'));
      await tester.pump();

      expect(find.text('Pengumuman'), findsOneWidget);
      expect(find.text('Post biasa'), findsNothing);
    });
  });

  testWidgets('avatar penulis dipapar di sebelah penggubah', (tester) async {
    await tester.pumpWidget(_host(management: false));
    await tester.pumpAndSettle();

    expect(find.byType(MemberAvatar), findsOneWidget);
  });

  // Kiraan "0/4" pada penggubah kosong cuma bunyi bising.
  testWidgets('kiraan gambar tersembunyi bila tiada gambar', (tester) async {
    await tester.pumpWidget(_host(management: false));
    await tester.pumpAndSettle();

    expect(find.textContaining('/4'), findsNothing);
  });

  testWidgets('medan teks fokus automatik', (tester) async {
    await tester.pumpWidget(_host(management: false));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
    // maxLines null = tumbuh dgn kandungan, bukan skrol dalam kotak tetap.
    expect(field.maxLines, isNull);
  });

  group('gaya penggubah', () {
    // inputDecorationTheme global set `filled: true` dgn
    // surfaceContainerHighest. Penggubah mesti menolaknya secara
    // eksplisit - `border: none` sahaja tinggalkan kotak kelabu.
    testWidgets('medan teks tiada isian dan tiada sempadan', (tester) async {
      await tester.pumpWidget(_host(management: false));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      final deco = field.decoration!;
      expect(deco.filled, isFalse, reason: 'medan masih berlatar kelabu');
      expect(deco.border, InputBorder.none);
      expect(deco.enabledBorder, InputBorder.none);
      expect(deco.focusedBorder, InputBorder.none);
    });
  });

  group('galeri dan kamera berasingan', () {
    testWidgets('dua butang media dipapar', (tester) async {
      await tester.pumpWidget(_host(management: false));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    });

    testWidgets('ada tooltip yang membezakan keduanya', (tester) async {
      await tester.pumpWidget(_host(management: false));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Pilih dari galeri'), findsOneWidget);
      expect(find.byTooltip('Ambil gambar'), findsOneWidget);
    });
  });
}
