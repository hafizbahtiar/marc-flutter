import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc_flutter/features/auth/widgets/auth_field.dart';
import 'package:marc_flutter/features/profile/profile_providers.dart';
import 'package:marc_flutter/shared/widgets/my_snackbar.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _seed(Profile p) {
    if (_seeded) return;
    _name.text = p.displayName ?? '';
    _phone.text = p.phone ?? '';
    _seeded = true;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .update(displayName: _name.text, phone: _phone.text);
      if (!mounted) return;
      MySnackBar.success(context, 'Profil dikemas kini.');
      context.pop();
    } catch (_) {
      if (!mounted) return;
      MySnackBar.error(context, 'Gagal simpan. Cuba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    profile.whenData((p) {
      if (p != null) _seed(p);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthField(
                  controller: _name,
                  label: 'Nama paparan',
                  icon: Icons.badge_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama diperlukan'
                      : null,
                ),
                const SizedBox(height: 16),
                AuthField(
                  controller: _phone,
                  label: 'No. telefon',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Simpan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
