import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/app/onesignal.dart';
import 'package:marc/app/router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/jwt.dart';
import 'package:marc/features/notifications/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env belum diisi — salin .env.example ke .env dan isi kredential.
  }
  await initOneSignal();

  // Baca token tersimpan dulu sebelum runApp, supaya redirect pertama
  // GoRouter betul terus (elak "flicker" ke /login sebelum sempat tahu
  // ada sesi tersimpan).
  final container = ProviderContainer();
  try {
    await container.read(authNotifierProvider.notifier).hydrate();
  } catch (_) {
    // Secure storage tak boleh diakses (cth: keystore rosak lepas
    // upgrade OS) — anggap logged out, biar user login semula.
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    ref.read(pushServiceProvider).startObserving();

    final initial = ref.read(authNotifierProvider);
    if (initial.isLoggedIn && initial.accessToken != null) {
      final userId = decodeJwtSubject(initial.accessToken!);
      if (userId != null) ref.read(pushServiceProvider).onSignedIn(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Segerak identiti OneSignal + simpan push id ikut status log masuk.
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      final push = ref.read(pushServiceProvider);
      final wasLoggedIn = previous?.isLoggedIn ?? false;

      if (next.isLoggedIn && !wasLoggedIn) {
        final userId = next.accessToken != null
            ? decodeJwtSubject(next.accessToken!)
            : null;
        if (userId != null) push.onSignedIn(userId);
      } else if (!next.isLoggedIn && wasLoggedIn) {
        push.onSignedOut();
      }
    });

    return MaterialApp.router(
      title: 'Marc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
