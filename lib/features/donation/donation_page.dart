import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

import 'donation_models.dart';
import 'donation_providers.dart';

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

  bool _submitting = false;
  bool _prefilled = false;

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

      final handler = ref.read(
        donationCheckoutHandlersProvider,
      )[response.gateway];
      if (handler == null) {
        if (mounted) {
          MySnackBar.error(context, 'Cara pembayaran ini belum disokong.');
        }
        return;
      }

      if (!mounted) return;
      // Stripe (PaymentSheet) papar sheet nativenya sendiri; gateway
      // hosted-redirect (ToyyibPay/SociaBuzz, akan datang) buka browser
      // luar — dua-dua tak perlukan borang tambahan dalam app ni,
      // `handle()` uruskan semuanya.
      final result = await handler.handle(context, response);
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

  @override
  Widget build(BuildContext context) {
    // `authNotifierProvider.isLoggedIn` sentiasa sedia sejurus (hydrated
    // sebelum `runApp`, lihat main.dart) — TIADA loading window. Guna
    // `myProfileProvider.valueOrNull` (async) untuk ni sebelum ni punca
    // bug: provider tu `null` sejurus page dibuka (masih loading), jadi
    // `requireEmail` sekejap jadi `true` (field emel muncul), pastu
    // bertukar `false` bila profil siap load (field hilang balik) —
    // nampak macam "emel dikosongkan" walhal cuma race loading-state.
    final isLoggedIn = ref.watch(
      authNotifierProvider.select((s) => s.isLoggedIn),
    );

    // Prefill nama/emel drpd profil SEKALI sahaja bila data sampai —
    // bukan setiap rebuild (elak overwrite apa yang user dah taip/edit
    // sendiri). Jawapan terus untuk "tak auto isi sendiri": sekarang ya.
    final profile = ref.watch(myProfileProvider).valueOrNull;
    if (!_prefilled && profile != null) {
      _prefilled = true;
      if (_nameController.text.isEmpty && (profile.displayName ?? '').isNotEmpty) {
        _nameController.text = profile.displayName!;
      }
      if (_emailController.text.isEmpty && profile.email.isNotEmpty) {
        _emailController.text = profile.email;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Donate')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _AmountForm(
            formKey: _formKey,
            amountController: _amountController,
            nameController: _nameController,
            emailController: _emailController,
            requireEmail: !isLoggedIn,
            submitting: _submitting,
            onSubmit: _startCheckout,
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
          // Ahli yang log masuk backend kaitkan user_id automatik
          // (OptionalAuth) dan boleh trace balik ke emel akaun terus,
          // jadi emel TAK wajib untuk mereka — tapi field ni tetap
          // dipapar & pre-fill drpd profil (bukan disorok), sebab kalau
          // disorok terus nampak macam borang "kosong"/pelik. Guest
          // (tak log masuk) wajib isi, sebab itu satu-satunya jejak yang
          // backend ada untuk mereka.
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: requireEmail ? 'Emel' : 'Emel (optional)',
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (!requireEmail && value.isEmpty) return null;
              if (value.isEmpty) return 'Emel diperlukan';
              if (!value.contains('@')) return 'Emel tidak sah';
              return null;
            },
          ),
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
