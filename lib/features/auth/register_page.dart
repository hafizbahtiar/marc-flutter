import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/auth/widgets/button_busy.dart';
import 'package:marc/shared/ui/form/custom_textfield.dart';
import 'package:marc/shared/utils/phone.dart';
import 'package:marc/shared/utils/validators.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _staffId = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _staffId.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Sahkan kata laluan diperlukan';
    }
    if (value != _password.text) {
      return 'Kata laluan tidak sepadan';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Form validator (validatePhone) dah sahkan format - normalizeMY
    // takkan pulang null di sini. Hantar bentuk TERNORMAL (bukan input
    // mentah pengguna) supaya backend/ToyyibPay terima bentuk konsisten
    // tak kira +60/60/0/dash/space yang ditaip.
    final ok = await ref
        .read(registerControllerProvider.notifier)
        .submit(
          _email.text.trim(),
          _password.text,
          normalizeMY(_phone.text) ?? _phone.text.trim(),
          staffId: _staffId.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      // Tak perlu context.pop() - signUp() dah setTokens(), authNotifier
      // punya isLoggedIn jadi true, router punya redirect auto navigate
      // ke /home terus. pop() manual di sini boleh clash dengan redirect
      // tu (dua-dua cuba navigate serentak lepas state auth berubah).
      MySnackBar.success(context, 'Pendaftaran berjaya.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerControllerProvider);
    final loading = state.isLoading;

    ref.listen(registerControllerProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        MySnackBar.error(context, '${next.error}');
      }
    });

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buat akaun',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Daftar dengan email anda.',
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
                  controller: _phone,
                  label: 'Nombor telefon',
                  hint: '012-3456789',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: validatePhone,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _staffId,
                  label: 'Nombor Staff',
                  hint: 'cth: 12345',
                  prefixIcon: Icons.badge_outlined,
                  validator: validateStaffId,
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
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _confirmPassword,
                  label: 'Sahkan kata laluan',
                  hint: 'Masukkan semula kata laluan',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const ButtonBusy(label: 'Sedang daftar…')
                      : const Text('Daftar →'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Sudah ada akaun?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Log masuk'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
