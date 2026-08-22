import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/auth/widgets/auth_field.dart';
import 'package:marc/features/auth/widgets/button_busy.dart';
import 'package:marc/shared/validators.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

/// Mesej selepas permintaan diterima.
///
/// SENGAJA neutral: backend pulang 204 sama ada akaun wujud atau tidak
/// (bukan-enumerasi, L32). Mesej yang berkata "Pautan dihantar!" akan
/// mengesahkan kewujudan akaun dan membatalkan keputusan itu di UI.
const forgotPasswordSentMessage =
    'Kalau emel itu berdaftar, kami dah hantar pautan reset. '
    'Semak peti masuk anda.';

/// 429 bermakna terlalu banyak percubaan, bukan permintaan tak sah —
/// pengguna patut cuba lagi sebentar, bukan menganggap ia gagal kekal.
bool isRetryableResetError(Object error) {
  return error is DioException && error.response?.statusCode == 429;
}

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(forgotPasswordControllerProvider.notifier)
        .submit(_email.text.trim());
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);
    final loading = state.isLoading;

    ref.listen(forgotPasswordControllerProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        MySnackBar.error(context, '${next.error}');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Lupa Kata Laluan')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: _sent
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      forgotPasswordSentMessage,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Masukkan emel akaun anda. Kami akan hantar pautan '
                        'untuk tetapkan kata laluan baharu.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      AuthField(
                        controller: _email,
                        label: 'Emel',
                        keyboardType: TextInputType.emailAddress,
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 28),
                      // `ButtonBusy` BUKAN butang — ia penunjuk sibuk
                      // (spinner + label) yang diletak SEBAGAI child
                      // butang. Corak ni disalin daripada
                      // `login_page.dart:82-87`.
                      FilledButton(
                        onPressed: loading ? null : _submit,
                        child: loading
                            ? const ButtonBusy(label: 'Sedang hantar…')
                            : const Text('Hantar pautan reset'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
