import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/posts/widgets/comment_tile.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/edit_text_dialog.dart';
import 'package:marc/shared/widgets/edited_badge.dart';

const _memberId = 'MARC2026/08/0001';

Comment _comment({String id = 'c1', String? parent, DateTime? editedAt}) =>
    Comment(
      id: id,
      parentCommentId: parent,
      content: 'kandungan comment $id',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      editedAt: editedAt,
      author: const Author(memberId: _memberId, displayName: 'Hafiz'),
      likeCount: 2,
      likedByMe: false,
    );

const _me = Profile(
  memberId: _memberId,
  email: 'ahli@contoh.com',
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

Widget _wrap(Widget child) => ProviderScope(
  overrides: [myProfileProvider.overrideWith((ref) async => _me)],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: ListView(children: [child])),
  ),
);

void main() {
  // Regresi: dulu `showEditTextDialog` buang TextEditingController dalam
  // blok `finally` sebaik `showDialog` selesai - tapi dialog masih
  // beranimasi keluar dan TextField masih dibina, jadi tekan Simpan/Batal
  // crash dengan "A TextEditingController was used after being disposed".
  group('showEditTextDialog tak guna controller selepas dispose', () {
    for (final action in ['Simpan', 'Batal']) {
      testWidgets('tekan $action', (tester) async {
        String? hasil;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      hasil = await showEditTextDialog(
                        context,
                        title: 'Edit comment',
                        initialValue: 'kandungan asal',
                        maxLines: 3,
                      );
                    },
                    child: const Text('buka'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('buka'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'kandungan baru');
        await tester.pump();

        await tester.tap(find.text(action));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(hasil, action == 'Simpan' ? 'kandungan baru' : isNull);
      });
    }
  });

  group('sheet tindakan comment', () {
    // Edit/Padam bukan lagi butang teks dalam baris comment - ia di
    // belakang satu ikon "lagi" yang buka sheet.
    testWidgets('Edit/Padam tak terpampang dalam baris', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommentThread(
            postId: 'p1',
            comment: _comment(),
            replies: const [],
            onReply: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Padam'), findsNothing);
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      expect(find.text('Balas'), findsOneWidget);
    });

    testWidgets('ikon lagi buka sheet dengan Edit + Padam', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommentThread(
            postId: 'p1',
            comment: _comment(),
            replies: [_comment(id: 'r1', parent: 'c1')],
            onReply: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Padam'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pilih Edit buka dialog edit', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommentThread(
            postId: 'p1',
            comment: _comment(),
            replies: const [],
            onReply: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Edit comment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Comment orang lain, viewer bukan management -> tiada titik masuk.
    testWidgets('tiada ikon lagi pada comment orang lain', (tester) async {
      final orangLain = Comment(
        id: 'c9',
        parentCommentId: null,
        content: 'comment orang lain',
        createdAt: DateTime.now(),
        editedAt: null,
        author: const Author(memberId: 'MARC2026/08/9999', displayName: 'Ali'),
        likeCount: 0,
        likedByMe: false,
      );

      await tester.pumpWidget(
        _wrap(
          CommentThread(
            postId: 'p1',
            comment: orangLain,
            replies: const [],
            onReply: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });
  });

  group('tag Disunting', () {
    testWidgets('tak muncul bila comment belum diedit', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommentThread(
            postId: 'p1',
            comment: _comment(),
            replies: const [],
            onReply: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EditedBadge), findsNothing);
    });

    testWidgets('muncul bila edited_at ada', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommentThread(
            postId: 'p1',
            comment: _comment(editedAt: DateTime.now()),
            replies: [
              _comment(id: 'r1', parent: 'c1', editedAt: DateTime.now()),
            ],
            onReply: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Satu untuk comment induk, satu untuk reply.
      expect(find.byType(EditedBadge), findsNWidgets(2));
      expect(find.text('Disunting'), findsNWidgets(2));
    });
  });
}
