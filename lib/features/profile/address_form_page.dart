import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/profile/address_providers.dart';
import 'package:marc/shared/widgets/app_action_sheet.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

/// Tambah/edit alamat. [existing] null = mod tambah, bukan null = mod edit
/// (medan diseed dari alamat sedia ada).
class AddressFormPage extends ConsumerStatefulWidget {
  const AddressFormPage({super.key, this.existing});

  final AddressRow? existing;

  bool get isEdit => existing != null;

  @override
  ConsumerState<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends ConsumerState<AddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _unitNumber = TextEditingController();
  final _floor = TextEditingController();
  final _block = TextEditingController();
  final _street = TextEditingController();
  final _township = TextEditingController();
  final _city = TextEditingController();
  final _postcode = TextEditingController();

  late String _addressType;
  String? _state;
  String? _stateError;
  late bool _isDefault;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _addressType = e?.addressType ?? 'landed';
    _state = e != null && kMalaysianStates.contains(e.state) ? e.state : null;
    _isDefault = e?.isDefault ?? false;
    _unitNumber.text = e?.unitNumber ?? '';
    _floor.text = e?.floor ?? '';
    _block.text = e?.block ?? '';
    _street.text = e?.street ?? '';
    _township.text = e?.township ?? '';
    _city.text = e?.city ?? '';
    _postcode.text = e?.postcode ?? '';
  }

  @override
  void dispose() {
    _unitNumber.dispose();
    _floor.dispose();
    _block.dispose();
    _street.dispose();
    _township.dispose();
    _city.dispose();
    _postcode.dispose();
    super.dispose();
  }

  /// Negeri guna action sheet (bukan `DropdownButtonFormField`) - senarai
  /// 16 negeri/wilayah lebih senang diimbas & ditekan sbg sheet, padanan
  /// corak pemilih lain dalam app (cth tukar role).
  Future<void> _pickState() async {
    final selected = await showAppActionSheet<String>(
      context,
      title: 'Pilih negeri',
      actions: [
        for (final s in kMalaysianStates)
          AppSheetAction(value: s, label: s, isSelected: s == _state),
      ],
    );
    if (selected == null) return;
    setState(() {
      _state = selected;
      _stateError = null;
    });
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    setState(() => _stateError = _state == null ? 'Negeri diperlukan' : null);
    if (!formValid || _state == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(addressRepositoryProvider);
      if (widget.isEdit) {
        await repo.update(
          widget.existing!.id,
          addressType: _addressType,
          unitNumber: _unitNumber.text.trim(),
          floor: _addressType == 'highrise' ? _floor.text.trim() : '',
          block: _addressType == 'highrise' ? _block.text.trim() : '',
          street: _street.text.trim(),
          township: _township.text.trim(),
          city: _city.text.trim(),
          postcode: _postcode.text.trim(),
          state: _state,
          isDefault: _isDefault,
        );
      } else {
        await repo.create(
          addressType: _addressType,
          unitNumber: _unitNumber.text.trim(),
          floor: _addressType == 'highrise' ? _floor.text.trim() : null,
          block: _addressType == 'highrise' ? _block.text.trim() : null,
          street: _street.text.trim(),
          township: _township.text.trim(),
          city: _city.text.trim(),
          postcode: _postcode.text.trim(),
          state: _state!,
          isDefault: _isDefault,
        );
      }
      if (!mounted) return;
      MySnackBar.success(context, 'Alamat disimpan.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      MySnackBar.error(
        context,
        e is DioException ? extractErrorMessage(e) : 'Gagal simpan. Cuba lagi.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHighrise = _addressType == 'highrise';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Alamat' : 'Tambah Alamat'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'landed', label: Text('Landed')),
                    ButtonSegment(value: 'highrise', label: Text('Highrise')),
                  ],
                  selected: {_addressType},
                  onSelectionChanged: (s) =>
                      setState(() => _addressType = s.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _unitNumber,
                  decoration: InputDecoration(
                    labelText: isHighrise ? 'No. unit' : 'No. rumah',
                  ),
                ),
                if (isHighrise) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _floor,
                    decoration: const InputDecoration(labelText: 'Tingkat'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _block,
                    decoration: const InputDecoration(labelText: 'Blok'),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _street,
                  decoration: const InputDecoration(labelText: 'Jalan'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _township,
                  decoration: const InputDecoration(labelText: 'Taman'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'Bandar'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Bandar diperlukan'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _postcode,
                  decoration: const InputDecoration(labelText: 'Poskod'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Poskod diperlukan';
                    if (!RegExp(r'^\d{5}$').hasMatch(value)) {
                      return 'Poskod mesti 5 digit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _pickState,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Negeri',
                      errorText: _stateError,
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _state ?? 'Pilih negeri',
                      style: _state == null
                          ? TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Jadikan alamat utama'),
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator.adaptive(),
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
