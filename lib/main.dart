import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/app/onesignal.dart';
import 'package:marc/app/router.dart';
import 'package:marc/app/stripe.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/device_label.dart';
import 'package:marc/core/jwt.dart';
import 'package:marc/core/theme_mode_provider.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/notifications/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Isi cache label peranti awal - elak login/refresh block pada
  // platform channel device_info_plus (lihat api_client.dart).
  unawaited(getDeviceLabel());

  // Pastikan trace PENUH sentiasa masuk console, bukan cuma ringkasan
  // mesej - susulan ralat "Looking up a deactivated widget's ancestor"
  // yang dilaporkan tanpa trace. `FlutterError.dumpErrorToConsole` default
  // pun buat ni, tapi eksplisit di sini elak kehilangan bila `onError`
  // lain (cth. Crashlytics kemudian) menggantikannya tanpa forward.
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
    debugPrint('[uncaught-flutter-error] ${details.exceptionAsString()}');
    debugPrint('[uncaught-flutter-error] stack:\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[uncaught-platform-error] $error\n$stack');
    return true;
  };
  // appFlavor null = `flutter run` tanpa --flavor (dev tempatan, guna
  // .env sedia ada). --flavor staging/prod pilih .env.staging/.env.prod.
  final envFile = switch (appFlavor) {
    'staging' => '.env.staging',
    'prod' => '.env.prod',
    _ => '.env',
  };
  try {
    await dotenv.load(fileName: envFile);
  } catch (_) {
    // .env belum diisi - salin .env.example ke .env dan isi kredential.
  }
  await initOneSignal();
  await initStripe();

  // Baca token tersimpan dulu sebelum runApp, supaya redirect pertama
  // GoRouter betul terus (elak "flicker" ke /login sebelum sempat tahu
  // ada sesi tersimpan).
  final container = ProviderContainer();
  try {
    await container.read(authNotifierProvider.notifier).hydrate();
  } catch (_) {
    // Secure storage tak boleh diakses (cth: keystore rosak lepas
    // upgrade OS) - anggap logged out, biar user login semula.
  }

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fire-and-forget - prompt OS boleh block indefinitely kalau user
    // backgroundkan app sebelum jawab, jadi jangan await sebelum UI
    // pertama render (lihat komen initOneSignal()).
    unawaited(requestNotificationPermission());
    ref.read(pushServiceProvider).startObserving();
    unawaited(ref.read(authServiceProvider).ensureFreshSession());

    final initial = ref.read(authNotifierProvider);
    if (initial.isLoggedIn && initial.accessToken != null) {
      final userId = decodeJwtSubject(initial.accessToken!);
      if (userId != null) ref.read(pushServiceProvider).onSignedIn(userId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(authServiceProvider).ensureFreshSession());
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
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
