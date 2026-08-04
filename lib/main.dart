import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc_flutter/app/onesignal.dart';
import 'package:marc_flutter/app/router.dart';
import 'package:marc_flutter/app/theme.dart';
import 'package:marc_flutter/features/auth/auth_providers.dart';
import 'package:marc_flutter/features/notifications/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env belum diisi — salin .env.example ke .env dan isi kredential.
  }
  await Supabase.initialize(
    url: dotenv.get('SUPABASE_URL'),
    publishableKey: dotenv.get('SUPABASE_ANON_KEY'),
  );
  await initOneSignal();
  runApp(const ProviderScope(child: MyApp()));
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
  }

  @override
  Widget build(BuildContext context) {
    // Segerak identiti OneSignal + simpan push id ikut sesi Supabase.
    ref.listen(authStateProvider, (previous, next) {
      final state = next.value;
      if (state == null) return;
      final session = state.session;
      final push = ref.read(pushServiceProvider);
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.initialSession:
          if (session != null) push.onSignedIn(session.user.id);
        case AuthChangeEvent.signedOut:
          push.onSignedOut();
        default:
          break;
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
