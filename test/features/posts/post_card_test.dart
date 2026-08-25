import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/posts/widgets/post_card.dart';
import 'package:marc/features/profile/profile_providers.dart';

Post _post() => Post(
  id: 'post-1',
  type: 'normal',
  content: 'kandungan post',
  createdAt: DateTime.now(),
  editedAt: null,
  author: const Author(
    userId: 'user-hafiz',
    memberId: 'MARC2026/08/0001',
    displayName: 'Hafiz',
  ),
  images: const [],
  likeCount: 0,
  commentCount: 0,
  likedByMe: false,
);

void main() {
  group('ketik nama penulis', () {
    testWidgets('navigasi ke skrin profil ahli, bukan buka post', (
      tester,
    ) async {
      var postTapped = false;
      final router = GoRouter(
        initialLocation: '/feed',
        routes: [
          GoRoute(
            path: '/feed',
            builder: (_, _) => Scaffold(
              body: ListView(
                children: [
                  PostCard(
                    post: _post(),
                    onTap: () => postTapped = true,
                    onToggleLike: () {},
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/members/:userId',
            builder: (_, state) => Scaffold(
              body: Text('profil-${state.pathParameters['userId']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [myProfileProvider.overrideWith((ref) async => null)],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hafiz'));
      await tester.pumpAndSettle();

      expect(find.text('profil-user-hafiz'), findsOneWidget);
      // Ketuk nama TAK patut turut buka post (dua destinasi berasingan).
      expect(postTapped, isFalse);
    });
  });
}
