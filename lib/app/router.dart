import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc_flutter/features/auth/login_page.dart';
import 'package:marc_flutter/features/auth/register_page.dart';
import 'package:marc_flutter/features/home/home_page.dart';
import 'package:marc_flutter/features/profile/profile_page.dart';

/// Adapter: dengar Stream, notify GoRouter untuk refresh redirect.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/register';
      if (loggedIn && onAuthPage) return '/home';
      if (!loggedIn && !onAuthPage) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
    ],
  );
});
