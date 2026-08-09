import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/nav_shell.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/features/auth/login_page.dart';
import 'package:marc/features/auth/register_page.dart';
import 'package:marc/features/audit/audit_page.dart';
import 'package:marc/features/donation/donation_page.dart';
import 'package:marc/features/members/members_page.dart';
import 'package:marc/features/members/pending_members_page.dart';
import 'package:marc/features/notifications/notifications_page.dart';
import 'package:marc/features/posts/create_post_page.dart';
import 'package:marc/features/posts/feed_page.dart';
import 'package:marc/features/posts/post_detail_page.dart';
import 'package:marc/features/profile/about_page.dart';
import 'package:marc/features/profile/edit_profile_page.dart';
import 'package:marc/features/profile/faq_page.dart';
import 'package:marc/features/profile/profile_page.dart';

/// Adapter: dengar perubahan authNotifierProvider, notify GoRouter untuk
/// refresh redirect. Gantian `GoRouterRefreshStream` yang dulu dengar
/// stream Supabase `onAuthStateChange`.
class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    _sub = ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (previous?.isLoggedIn != next.isLoggedIn) notifyListeners();
    });
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _GoRouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authNotifierProvider).isLoggedIn;
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/register';
      if (loggedIn && onAuthPage) return '/feed';
      if (!loggedIn && !onAuthPage) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: '/edit-profile',
        builder: (_, _) => const EditProfilePage(),
      ),
      GoRoute(path: '/about', builder: (_, _) => const AboutPage()),
      GoRoute(path: '/faq', builder: (_, _) => const FaqPage()),
      GoRoute(path: '/donate', builder: (_, _) => const DonationPage()),
      GoRoute(path: '/members', builder: (_, _) => const MembersPage()),
      GoRoute(path: '/audit-logs', builder: (_, _) => const AuditPage()),
      GoRoute(
        path: '/members/pending',
        builder: (_, _) => const PendingMembersPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(path: '/posts/new', builder: (_, _) => const CreatePostPage()),
      GoRoute(
        path: '/posts/:id',
        builder: (_, state) =>
            PostDetailPage(postId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => NavShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/feed', builder: (_, _) => const FeedPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
            ],
          ),
        ],
      ),
    ],
  );
});
