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
        return const _AuthSwitcher();
      },
    );
  }
}

class _AuthSwitcher extends StatefulWidget {
  const _AuthSwitcher();

  @override
  State<_AuthSwitcher> createState() => _AuthSwitcherState();
}

class _AuthSwitcherState extends State<_AuthSwitcher> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    if (_showRegister) {
      return RegisterPage(
        onLoginTap: () => setState(() => _showRegister = false),
      );
    }
    return LoginPage(
      onRegisterTap: () => setState(() => _showRegister = true),
    );
  }
}