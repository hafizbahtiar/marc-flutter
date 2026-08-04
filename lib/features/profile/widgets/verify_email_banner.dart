import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc_flutter/app/theme.dart';
import 'package:marc_flutter/features/profile/profile_providers.dart';
import 'package:marc_flutter/shared/widgets/my_snackbar.dart';

/// Banner amaran "email belum disahkan". Papar hanya bila profil dimuat
/// dan `email_verified == false`. Butang buka sheet masukkan kod OTP.
class VerifyEmailBanner extends ConsumerWidget {
  const VerifyEmailBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final verified = profile.valueOrNull?.emailVerified ?? true;
    if (verified) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined,
              size: 20, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Email anda belum disahkan.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          TextButton(
            onPressed: () => showVerifyEmailSheet(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('Sahkan'),
          ),
        ],
      ),
    );
  }
}

Future<void> showVerifyEmailSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _VerifyEmailSheet(),
  );
}

class _VerifyEmailSheet extends ConsumerStatefulWidget {
  const _VerifyEmailSheet();

  @override
  ConsumerState<_VerifyEmailSheet> createState() => _VerifyEmailSheetState();
}

class _VerifyEmailSheetState extends ConsumerState<_VerifyEmailSheet> {
  final _code = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  bool _sent = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref.read(emailVerificationProvider).sendCode();
      if (!mounted) return;
      setState(() => _sent = true);
      MySnackBar.info(context, 'Kod dihantar ke email anda.');
    } catch (_) {
      if (mounted) MySnackBar.error(context, 'Gagal hantar kod. Cuba lagi.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length < 6) {
      MySnackBar.error(context, 'Masukkan kod 6 digit.');
      return;
    }
    setState(() => _verifying = true);
    try {
      await ref.read(emailVerificationProvider).verifyCode(_code.text);
      if (!mounted) return;
      // Papar sebelum pop supaya snackbar kekal selepas sheet ditutup.
      MySnackBar.success(context, 'Email berjaya disahkan.');
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) MySnackBar.error(context, 'Kod tidak sah atau tamat tempoh.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.read(emailVerificationProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sahkan email',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            _sent
                ? 'Masukkan kod 6 digit yang dihantar ke email anda.'
                : 'Kami akan hantar kod pengesahan ke email anda.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (_sent) ...[
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Kod pengesahan',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _verifying ? null : _verify,
              child: _verifying
                  ? const _Busy()
                  : const Text('Sahkan  →'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _sending ? null : _send,
              child: const Text('Hantar semula kod'),
            ),
          ] else
            FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending ? const _Busy() : const Text('Hantar kod  →'),
            ),
          if (email.emailForDisplay != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                email.emailForDisplay!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 16,
      width: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
