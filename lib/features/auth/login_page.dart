import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/auth/widgets/button_busy.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';
import 'package:marc/shared/ui/form/custom_textfield.dart';
import 'package:marc/shared/utils/validators.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(authNotifierProvider).endReason !=
          AuthEndReason.sessionEnded) {
        return;
      }
      ref.read(authNotifierProvider.notifier).consumeEndReason();
      showAppAlertDialog(
        context,
        title: sessionEndedTitle,
        message: sessionEndedMessage,
      );
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(loginControllerProvider.notifier)
        .submit(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final loading = state.isLoading;

    ref.listen(loginControllerProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        MySnackBar.error(context, '${next.error}');
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 72, 28, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat kembali',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Log masuk untuk teruskan.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 40),
                CustomTextField(
                  controller: _email,
                  label: 'Email',
                  hint: 'nama@contoh.com',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _password,
                  label: 'Kata laluan',
                  hint: 'Masukkan kata laluan',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: validatePassword,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const ButtonBusy(label: 'Sedang log masuk…')
                      : const Text('Log masuk →'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Belum ada akaun?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Daftar'),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Lupa kata laluan?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
