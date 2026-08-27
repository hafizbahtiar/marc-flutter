import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/posts/feed_page.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/data/local_drafts_repository.dart';

import '../../support/fake_draft_repository.dart';

Profile _approvedProfile() => Profile(
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

/// [FeedNotifier] palsu - build() pulangkan [FeedState] kosong serta-merta
/// tanpa sentuh dio/auth sebenar. Ujian badge FAB ni cuma pasal
/// [hasNewPostDraftProvider], bukan tentang muatan feed itu sendiri.
class _FakeFeedNotifier extends FeedNotifier {
  @override
  Future<FeedState> build() async => const FeedState();
}

Widget _host({required DraftRepository draftRepository}) => ProviderScope(
  overrides: [
    myProfileProvider.overrideWith((ref) async => _approvedProfile()),
    feedProvider.overrideWith(_FakeFeedNotifier.new),
    draftRepositoryProvider.overrideWithValue(draftRepository),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const FeedPage()),
);

Finder _badgeFinder() => find.byType(Badge);

void main() {
  testWidgets('FAB tiada badge bila tiada draf new_post', (tester) async {
    await tester.pumpWidget(_host(draftRepository: FakeDraftRepository()));
    await tester.pumpAndSettle();

    final badge = tester.widget<Badge>(_badgeFinder());
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('FAB papar badge bila draf new_post wujud', (tester) async {
    final repo = FakeDraftRepository();
    await repo.save('new_post', kind: 'post', content: 'draf belum hantar');

    await tester.pumpWidget(_host(draftRepository: repo));
    await tester.pumpAndSettle();

    final badge = tester.widget<Badge>(_badgeFinder());
    expect(badge.isLabelVisible, isTrue);
  });
}
