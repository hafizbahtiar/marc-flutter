import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

/// Banner "email belum disahkan". Papar hanya bila profil dimuat dan
/// `email_verified == false`. Butang "Sahkan" panggil
/// `POST /auth/verify-email/request` - backend hantar link pengesahan
/// melalui email (Resend).
class VerifyEmailBanner extends ConsumerStatefulWidget {
  const VerifyEmailBanner({super.key});

  @override
  ConsumerState<VerifyEmailBanner> createState() => _VerifyEmailBannerState();
}

class _VerifyEmailBannerState extends ConsumerState<VerifyEmailBanner> {
  bool _sending = false;

  Future<void> _requestVerification() async {
    setState(() => _sending = true);
    try {
      await ref.read(dioProvider).post('/auth/verify-email/request');
      if (!mounted) return;
      MySnackBar.success(
        context,
        'Email pengesahan dihantar. Sila semak inbox anda.',
      );
    } catch (e) {
      if (!mounted) return;
      MySnackBar.error(
        context,
        e is DioException
            ? extractErrorMessage(e)
            : 'Gagal hantar email pengesahan. Cuba lagi.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    final verified = profile.valueOrNull?.emailVerified ?? true;
    if (verified) return const SizedBox.shrink();

    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: semantic.warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.mark_email_unread_outlined, color: semantic.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Email anda belum disahkan.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: semantic.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _sending ? null : _requestVerification,
            style: TextButton.styleFrom(foregroundColor: semantic.warning),
            child: _sending
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator.adaptive(),
                  )
                : const Text('Sahkan'),
          ),
        ],
      ),
    );
  }
}
