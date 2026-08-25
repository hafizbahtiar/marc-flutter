import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/posts/create_post_page.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/local_drafts_repository.dart';
import 'package:marc/shared/widgets/member_avatar.dart';

import '../../support/fake_draft_repository.dart';

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

Widget _host({required bool management, DraftRepository? draftRepository}) =>
    ProviderScope(
      overrides: [
        myProfileProvider.overrideWith(
          (ref) async => _profile(management: management),
        ),
        draftRepositoryProvider.overrideWithValue(
          draftRepository ?? FakeDraftRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        // Dibungkus dengan skrin permulaan + push, supaya CreatePostPage
        // ada back button (Navigator.canPop true) untuk tester.pageBack()
        // uji gerak isyarat keluar.
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CreatePostPage())),
            child: const Text('buka'),
          ),
        ),
      ),
    );

Future<void> _openComposer(
  WidgetTester tester, {
  required bool management,
}) async {
  await tester.pumpWidget(_host(management: management));
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

FilledButton _sendButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Hantar'));

void main() {
  group('butang hantar', () {
    // Dulu penggubah menerima ketukan pada penggubah kosong dan membalas
    // dengan snackbar ralat. Butang mati menyatakan perkara sama sebelum
    // pengguna cuba.
    testWidgets('mati bila tiada teks dan tiada gambar', (tester) async {
      await _openComposer(tester, management: false);

      expect(_sendButton(tester).onPressed, isNull);
    });

    testWidgets('hidup sebaik ada teks', (tester) async {
      await _openComposer(tester, management: false);

      await tester.enterText(find.byType(TextField), 'Assalamualaikum semua');
      await tester.pump();

      expect(_sendButton(tester).onPressed, isNotNull);
    });

    testWidgets('kekal mati untuk ruang kosong sahaja', (tester) async {
      await _openComposer(tester, management: false);

      await tester.enterText(find.byType(TextField), '     ');
      await tester.pump();

      expect(_sendButton(tester).onPressed, isNull);
    });
  });

  group('pil pengumuman', () {
    testWidgets('tersembunyi untuk ahli biasa', (tester) async {
      await _openComposer(tester, management: false);

      expect(find.text('Post biasa'), findsNothing);
      expect(find.text('Pengumuman'), findsNothing);
    });

    testWidgets('management nampak, dan boleh toggle', (tester) async {
      await _openComposer(tester, management: true);

      expect(find.text('Post biasa'), findsOneWidget);

      await tester.tap(find.text('Post biasa'));
      await tester.pump();

      expect(find.text('Pengumuman'), findsOneWidget);
      expect(find.text('Post biasa'), findsNothing);
    });
  });

  testWidgets('avatar penulis dipapar di sebelah penggubah', (tester) async {
    await _openComposer(tester, management: false);

    expect(find.byType(MemberAvatar), findsOneWidget);
  });

  // Kiraan "0/4" pada penggubah kosong cuma bunyi bising.
  testWidgets('kiraan gambar tersembunyi bila tiada gambar', (tester) async {
    await _openComposer(tester, management: false);

    expect(find.textContaining('/4'), findsNothing);
  });

  testWidgets('medan teks fokus automatik', (tester) async {
    await _openComposer(tester, management: false);

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
      await _openComposer(tester, management: false);

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
      await _openComposer(tester, management: false);

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    });

    testWidgets('ada tooltip yang membezakan keduanya', (tester) async {
      await _openComposer(tester, management: false);

      expect(find.byTooltip('Pilih dari galeri'), findsOneWidget);
      expect(find.byTooltip('Ambil gambar'), findsOneWidget);
    });
  });

  group('draf', () {
    testWidgets('draf sedia ada auto-isi medan teks bila composer dibuka', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await repo.save('new_post', kind: 'post', content: 'draf lama saya');

      await _openComposer(tester, management: false);
      // Tanpa reset ini, pumpWidget() seterusnya cuma UPDATE elemen root
      // sedia ada (Navigator kekal dengan CreatePostPage lama masih di
      // atas timbunan) - kosongkan dulu supaya tester.pumpWidget()
      // berikutnya bina semula pokok widget dari kosong.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_host(management: false, draftRepository: repo));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('draf lama saya'), findsOneWidget);
    });

    testWidgets('tiada dialog keluar bila composer kosong', (tester) async {
      await _openComposer(tester, management: false);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Simpan sebagai draf?'), findsNothing);
      expect(find.byType(CreatePostPage), findsNothing);
    });

    testWidgets(
      'dialog keluar muncul bila ada teks belum dihantar, Batal kekalkan composer',
      (tester) async {
        await _openComposer(tester, management: false);
        await tester.enterText(find.byType(TextField), 'sedang menaip...');
        await tester.pump();

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('Simpan sebagai draf?'), findsOneWidget);

        // Sheet Material tak ada baris "Batal" eksplisit (beza dgn
        // Cupertino) - ketik luar sheet (barrier) ialah cara batal, sama
        // makna dgn Batal (showAppActionSheet pulangkan null).
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        expect(find.byType(CreatePostPage), findsOneWidget);
        expect(find.text('sedang menaip...'), findsOneWidget);
      },
    );

    testWidgets('pilih Simpan draf menulis ke repository dan tutup composer', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await _openComposer(tester, management: false);
      // Reset pokok widget dulu - tanpa ni Navigator kekal dgn
      // CreatePostPage lama masih di atas timbunan lepas pumpWidget().
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_host(management: false, draftRepository: repo));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'simpan ni');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan draf'));
      await tester.pumpAndSettle();

      expect(find.byType(CreatePostPage), findsNothing);
      final saved = await repo.get('new_post');
      expect(saved!.content, 'simpan ni');
    });

    testWidgets(
      'pilih Buang memadam draf sedia ada dan tutup composer tanpa simpan',
      (tester) async {
        final repo = FakeDraftRepository();
        await repo.save('new_post', kind: 'post', content: 'draf lama');
        await tester.pumpWidget(
          _host(management: false, draftRepository: repo),
        );
        await tester.tap(find.text('buka'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'draf lama diubah');
        await tester.pump();
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Buang'));
        await tester.pumpAndSettle();

        expect(find.byType(CreatePostPage), findsNothing);
        expect(await repo.get('new_post'), isNull);
      },
    );

    testWidgets('padam draf dari menu AppBar kosongkan medan & buang dari storan', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await repo.save('new_post', kind: 'post', content: 'draf lama saya');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_host(management: false, draftRepository: repo));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('draf lama saya'), findsOneWidget);
      expect(find.byTooltip('Padam draf'), findsOneWidget);

      await tester.tap(find.byTooltip('Padam draf'));
      await tester.pumpAndSettle();
      expect(find.text('Padam draf?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Padam draf'));
      await tester.pumpAndSettle();

      expect(find.text('draf lama saya'), findsNothing);
      expect(find.byTooltip('Padam draf'), findsNothing);
      expect(await repo.get('new_post'), isNull);
      expect(find.text('Draf dipadam.'), findsOneWidget);
    });

    testWidgets(
      'kegagalan storan draf tak perangkap pengguna - snackbar dipapar, composer tetap tutup',
      (tester) async {
        final repo = ThrowingDraftRepository();
        await tester.pumpWidget(
          _host(management: false, draftRepository: repo),
        );
        await tester.tap(find.text('buka'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'teks belum hantar');
        await tester.pump();
        await tester.pageBack();
        await tester.pumpAndSettle();

        // Bukan pumpAndSettle - SnackBar ada Timer 3 saat, pumpAndSettle
        // laju-lajukan masa maya sampai Timer tu tamat dan SnackBar hilang
        // sebelum expect sempat jalan. Satu pump cukup untuk selesaikan
        // try/catch + pop (Navigator.pop dialog selesai serta-merta, tak
        // tunggu animasi) - semak SnackBar SEBAIK frame itu, sebelum
        // majukan lagi untuk siapkan animasi peralihan route pop.
        await tester.tap(find.text('Simpan draf'));
        await tester.pump();
        expect(find.text('Gagal simpan draf.'), findsOneWidget);

        // Kini boleh guna pumpAndSettle - dah rakam bukti SnackBar wujud
        // di atas, jadi tak kisah ia hilang semasa settle ni.
        await tester.pumpAndSettle();
        expect(find.byType(CreatePostPage), findsNothing);
      },
    );
  });
}
