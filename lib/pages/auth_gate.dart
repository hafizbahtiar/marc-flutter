import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc_flutter/pages/home_page.dart';
import 'package:marc_flutter/pages/login_page.dart';
import 'package:marc_flutter/pages/register_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        Supabase.instance.client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session != null) {
          return const HomePage();
        }
        return Navigator(
          onGenerateRoute: (settings) {
            if (settings.name == '/register') {
              return MaterialPageRoute(
                builder: (_) => RegisterPage(
                  onLoginTap: () => Navigator.pop(context),
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => LoginPage(
                onRegisterTap: () => Navigator.pushNamed(context, '/register'),
              ),
            );
          },
        );
      },
    );
  }
}