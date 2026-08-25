import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/posts/post_detail_page.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/local_drafts_repository.dart';

import '../../support/fake_draft_repository.dart';

Comment _comment(String id) => Comment(
  id: id,
  parentCommentId: null,
  content: 'comment $id',
  createdAt: DateTime(2026, 8, 25),
  editedAt: null,
  author: const Author(
    userId: 'user-zul',
    memberId: 'MARC2026/08/0003',
    displayName: 'Zul',
  ),
  likeCount: 0,
  likedByMe: false,
);

Post _post() => Post(
  id: 'post-1',
  type: 'normal',
  content: 'Post asal',
  createdAt: DateTime(2026, 8, 25),
  editedAt: null,
  author: const Author(
    userId: 'user-aina',
    memberId: 'MARC2026/08/0002',
    displayName: 'Aina',
  ),
  images: const [],
  likeCount: 0,
  commentCount: 0,
  likedByMe: false,
);

Profile _profile() => Profile(
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

Widget _host({DraftRepository? draftRepository, List<Comment>? comments}) =>
    ProviderScope(
      overrides: [
        myProfileProvider.overrideWith((ref) async => _profile()),
        postDetailProvider.overrideWith((ref, id) async => _post()),
        commentsProvider.overrideWith(
          (ref, id) async => comments ?? const <Comment>[],
        ),
        draftRepositoryProvider.overrideWithValue(
          draftRepository ?? FakeDraftRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PostDetailPage(postId: 'post-1'),
              ),
            ),
            child: const Text('buka'),
          ),
        ),
      ),
    );

Future<void> _openPostDetail(WidgetTester tester) async {
  await tester.pumpWidget(_host());
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

void main() {
  group('draf comment', () {
    testWidgets('draf sedia ada untuk root auto-isi medan comment', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await repo.save(
        'reply:post-1:root',
        kind: 'comment',
        content: 'draf balasan',
      );

      await tester.pumpWidget(_host(draftRepository: repo));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('draf balasan'), findsOneWidget);
    });

    testWidgets('tiada dialog keluar bila medan comment kosong', (
      tester,
    ) async {
      await _openPostDetail(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Simpan sebagai draf?'), findsNothing);
      expect(find.byType(PostDetailPage), findsNothing);
    });

    testWidgets('pilih Simpan draf tulis ke key root dan tutup skrin', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await tester.pumpWidget(_host(draftRepository: repo));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'comment belum hantar');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan draf'));
      await tester.pumpAndSettle();

      expect(find.byType(PostDetailPage), findsNothing);
      final saved = await repo.get('reply:post-1:root');
      expect(saved!.content, 'comment belum hantar');
      expect(saved.kind, 'comment');
    });

    testWidgets('pilih Buang memadam draf dan tutup skrin tanpa simpan', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await tester.pumpWidget(_host(draftRepository: repo));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nak dibuang');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buang'));
      await tester.pumpAndSettle();

      expect(find.byType(PostDetailPage), findsNothing);
      expect(await repo.get('reply:post-1:root'), isNull);
    });

    // Finding 2: _restoreDraft() mesti setState supaya PopScope.canPop
    // dapat rebuild dan tercermin draf yang dipulihkan secara senyap -
    // tanpa ni, canPop kekal `true` dari binaan pertama (medan kosong)
    // walaupun medan dah diisi draf, jadi back gesture terus pop senyap
    // tanpa dialog.
    //
    // repo yang tangguhkan get() sampai lepas pembukaan settle penuh -
    // kalau tak, rebuild TAK BERKAITAN dari postDetailProvider/
    // commentsProvider yang turut resolve semasa pembukaan boleh secara
    // kebetulan "betulkan" canPop dan sorokkan bug setState yang hilang.
    testWidgets(
      'draf root dipulihkan secara senyap tetap cetuskan dialog keluar bila cuba tinggal',
      (tester) async {
        final inner = FakeDraftRepository();
        await inner.save(
          'reply:post-1:root',
          kind: 'comment',
          content: 'draf lama',
        );
        final repo = DelayedGetDraftRepository(inner);

        await tester.pumpWidget(_host(draftRepository: repo));
        await tester.tap(find.text('buka'));
        // Provider post/comments settle penuh di sini - get() draf masih
        // tergantung (gate belum dilepaskan).
        await tester.pumpAndSettle();

        repo.release();
        // Beberapa pump untuk selesaikan rantaian get() (dua await
        // berturutan dalam DelayedGetDraftRepository) dan seterusnya
        // setState yang membina semula PopScope dengan canPop terkini -
        // tiada lagi rebuild lain yang tergantung selepas ni.
        await tester.pump();
        await tester.pump();
        await tester.pump();

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('Simpan sebagai draf?'), findsOneWidget);
      },
    );

    testWidgets(
      'kegagalan storan draf tak perangkap pengguna - snackbar dipapar, skrin tetap tutup',
      (tester) async {
        final repo = ThrowingDraftRepository();
        await tester.pumpWidget(_host(draftRepository: repo));
        await tester.tap(find.text('buka'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'comment belum hantar');
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
        expect(find.byType(PostDetailPage), findsNothing);
      },
    );
  });

  group('draf bertukar sasaran balas', () {
    // Finding 1: draf reply-keyed (reply:{postId}:{commentId}) hanya
    // ditulis, tak pernah dibaca balik kecuali kunci root - bertukar
    // sasaran balas (Balas / tutup-X) mesti cuba pulihkan draf sasaran
    // BARU, tapi tak boleh menimpa teks belum dihantar yang sedang ditaip.
    testWidgets('tekan Balas pulihkan draf sasaran baru ke medan yang kosong', (
      tester,
    ) async {
      final repo = FakeDraftRepository();
      await repo.save(
        'reply:post-1:c1',
        kind: 'comment',
        content: 'balasan untuk c1',
      );

      await tester.pumpWidget(
        _host(draftRepository: repo, comments: [_comment('c1')]),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Balas'));
      await tester.pumpAndSettle();

      expect(find.text('balasan untuk c1'), findsOneWidget);
    });

    testWidgets(
      'tekan Balas TAK menimpa teks belum dihantar yang sedang ditaip',
      (tester) async {
        final repo = FakeDraftRepository();
        await repo.save(
          'reply:post-1:c1',
          kind: 'comment',
          content: 'balasan untuk c1',
        );

        await tester.pumpWidget(
          _host(draftRepository: repo, comments: [_comment('c1')]),
        );
        await tester.tap(find.text('buka'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'sedang menaip...');
        await tester.pump();

        await tester.tap(find.text('Balas'));
        await tester.pumpAndSettle();

        expect(find.text('sedang menaip...'), findsOneWidget);
        expect(find.text('balasan untuk c1'), findsNothing);
      },
    );

    testWidgets(
      'butang tutup-X kembali ke root pulihkan draf root ke medan yang dikosongkan',
      (tester) async {
        final repo = FakeDraftRepository();
        await repo.save(
          'reply:post-1:root',
          kind: 'comment',
          content: 'draf root',
        );

        await tester.pumpWidget(
          _host(draftRepository: repo, comments: [_comment('c1')]),
        );
        await tester.tap(find.text('buka'));
        await tester.pumpAndSettle();

        // Medan dah terisi draf root dari initState - tukar sasaran ke c1
        // (tiada draf c1, jadi tiada kesan), kosongkan medan secara
        // manual, pastikan tutup-X pulihkan balik draf root sebab medan
        // sekarang kosong.
        await tester.tap(find.text('Balas'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '');
        await tester.pump();

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.text('draf root'), findsOneWidget);
      },
    );
  });
}
