import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

/// Paparan "sahkan emel dahulu" - dikongsi Feed dan Dashboard. Diekstrak
/// daripada feed_page.dart bila Dashboard jadi tab Utama: dua salinan
/// borang hantar-semula-emel akan menyimpang, dan borang itu ialah
/// satu-satunya jalan keluar untuk ahli approved yang belum sahkan emel.
class EmailNotVerifiedView extends ConsumerStatefulWidget {
  const EmailNotVerifiedView({super.key, required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  ConsumerState<EmailNotVerifiedView> createState() =>
      _EmailNotVerifiedViewState();
}

class _EmailNotVerifiedViewState extends ConsumerState<EmailNotVerifiedView> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('MARC')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 48,
                  color: Theme.of(
                    context,
                  ).extension<AppSemanticColors>()!.warning,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sila sahkan email anda untuk teruskan.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: _sending ? null : _requestVerification,
                      child: _sending
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator.adaptive(),
                            )
                          : const Text('Hantar semula'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: widget.onRefresh,
                      child: const Text('Semak semula'),
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
