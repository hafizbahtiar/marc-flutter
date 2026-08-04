import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc_flutter/app/theme.dart';
import 'package:marc_flutter/features/profile/profile_providers.dart';
import 'package:marc_flutter/shared/widgets/my_snackbar.dart';

/// Banner "email belum disahkan". Papar hanya bila profil dimuat dan
/// `email_verified == false`.
///
/// Buat masa ini butang "Sahkan" hanya papar snackbar — fungsi pengesahan
/// sebenar akan datang (perlu custom SMTP).
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
            onPressed: () => MySnackBar.info(
              context,
              'Pengesahan email akan datang.',
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('Sahkan'),
          ),
        ],
      ),
    );
  }
}
