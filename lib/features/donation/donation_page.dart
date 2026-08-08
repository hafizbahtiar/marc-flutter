import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

import 'donation_models.dart';
import 'donation_providers.dart';

enum _Step { amount, confirm }

class DonationPage extends ConsumerStatefulWidget {
  const DonationPage({super.key});

  @override
  ConsumerState<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends ConsumerState<DonationPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  _Step _step = _Step.amount;
  DonationCheckoutResponse? _checkout;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _startCheckout() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < 1) {
      MySnackBar.error(context, 'Amount tidak sah.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final response = await ref
          .read(donationRepositoryProvider)
          .checkout(
            amountCents: (amount * 100).round(),
            donorName: _nameController.text.trim().isEmpty
                ? null
                : _nameController.text.trim(),
            donorEmail: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
          );

      final handlers = ref.read(donationCheckoutHandlersProvider);
      if (!handlers.containsKey(response.gateway)) {
        if (mounted) {
          MySnackBar.error(context, 'Cara pembayaran ini belum disokong.');
        }
        return;
      }

      if (!mounted) return;
      // Gateway client-side confirm (Stripe) perlu papar borang kad
      // dulu (_Step.confirm) sebelum handler.handle() boleh dipanggil.
      // Gateway hosted-redirect terus panggil handler (tiada borang
      // tambahan diperlukan di app ni).
      if (response.clientSecret != null) {
        setState(() {
          _checkout = response;
          _step = _Step.confirm;
        });
      } else {
        await _completeWithHandler(response);
      }
    } catch (e) {
      if (mounted) {
        MySnackBar.error(
          context,
          e is DioException
              ? extractErrorMessage(e)
              : 'Gagal mulakan donation. Cuba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmPayment() async {
    final checkout = _checkout;
    if (checkout == null) return;
    setState(() => _submitting = true);
    await _completeWithHandler(checkout);
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _completeWithHandler(DonationCheckoutResponse response) async {
    final handler = ref.read(
      donationCheckoutHandlersProvider,
    )[response.gateway]!;
    final result = await handler.handle(response);

    if (!mounted) return;
    switch (result.outcome) {
      case DonationOutcome.success:
        MySnackBar.success(context, 'Terima kasih atas sumbangan anda!');
        Navigator.of(context).pop();
      case DonationOutcome.cancelled:
        break;
      case DonationOutcome.failure:
        MySnackBar.error(context, result.message ?? 'Pembayaran gagal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn =
        ref.watch(myProfileProvider).valueOrNull?.email.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Donate')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _step == _Step.amount
              ? _AmountForm(
                  formKey: _formKey,
                  amountController: _amountController,
                  nameController: _nameController,
                  emailController: _emailController,
                  requireEmail: !isLoggedIn,
                  submitting: _submitting,
                  onSubmit: _startCheckout,
                )
              : _ConfirmStep(
                  submitting: _submitting,
                  onConfirm: _confirmPayment,
                  onBack: () => setState(() => _step = _Step.amount),
                ),
        ),
      ),
    );
  }
}

class _AmountForm extends StatelessWidget {
  const _AmountForm({
    required this.formKey,
    required this.amountController,
    required this.nameController,
    required this.emailController,
    required this.requireEmail,
    required this.submitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController amountController;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final bool requireEmail;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sumbangan anda membantu kami terus membangunkan MARC.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (RM)',
              prefixText: 'RM ',
            ),
            validator: (v) {
              final amount = double.tryParse((v ?? '').trim());
              if (amount == null || amount < 1) return 'Amount tidak sah';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nama (optional)'),
          ),
          // Ahli yang log masuk tak perlu isi emel — backend kaitkan
          // user_id automatik (OptionalAuth) dan boleh trace balik ke
          // emel akaun terus, tak perlu duplicate input di sini. Cuma
          // guest (tak log masuk) yang wajib isi, sebab itu satu-satunya
          // jejak yang backend ada untuk mereka.
          if (requireEmail) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Emel'),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Emel diperlukan';
                if (!value.contains('@')) return 'Emel tidak sah';
                return null;
              },
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: submitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator.adaptive(),
                  )
                : const Text('Teruskan'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.submitting,
    required this.onConfirm,
    required this.onBack,
  });

  final bool submitting;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Maklumat kad', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        // Padanan gaya TextFormField app ni (lihat theme.dart
        // inputDecorationTheme): filled fieldFill, borderless, radius 12.
        // CardFormField sebelum ni tiada backgroundColor eksplisit — jatuh
        // balik ke default Material native (jarang match brand, kadang
        // teks/bg jadi sama warna = field "hilang").
        CardFormField(
          countryCode: 'MY',
          style: CardFormStyle(
            backgroundColor: AppColors.fieldFill,
            borderColor: AppColors.fieldFill,
            borderWidth: 0,
            borderRadius: 12,
            textColor: AppColors.ink,
            placeholderColor: AppColors.muted,
            cursorColor: AppColors.accent,
            textErrorColor: AppColors.error,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: submitting ? null : onConfirm,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator.adaptive(),
                )
              : const Text('Bayar'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: submitting ? null : onBack,
          child: const Text('Kembali'),
        ),
      ],
    );
  }
}
