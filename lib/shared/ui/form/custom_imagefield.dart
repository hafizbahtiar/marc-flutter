import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marc/shared/ui/form/custom_textfield.dart';
import 'package:marc/shared/ui/media/app_network_image.dart';

/// Satu gambar untuk borang: tapak kosong, pratonton URL, atau fail baru.
///
/// Paparan rangkaian melalui [AppNetworkImage] (bukan `Image.network`).
/// Pemilih boleh di-inject ([pickImage]) supaya ujian tak buka galeri.
class CustomImageField extends StatelessWidget {
  const CustomImageField({
    super.key,
    required this.label,
    this.value,
    this.previewUrl,
    this.onChanged,
    this.pickImage,
    this.validator,
    this.enabled = true,
    this.addLabel = 'Tambah gambar',
  });

  final String label;
  final XFile? value;
  final String? previewUrl;
  final ValueChanged<XFile?>? onChanged;

  /// Override pemilih lalai (`ImagePicker` galeri, max 2048px).
  final Future<XFile?> Function()? pickImage;
  final FormFieldValidator<XFile?>? validator;
  final bool enabled;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return FormField<XFile?>(
      initialValue: value,
      validator: (v) => validator?.call(value ?? v),
      builder: (field) {
        final file = value ?? field.value;
        final url = previewUrl?.trim();
        final hasUrl = url != null && url.isNotEmpty;
        final hasImage = file != null || hasUrl;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormFieldLabel(label, enabled: enabled),
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? () => _pick(field) : null,
                  child: hasImage
                      ? _Preview(
                          file: file,
                          url: hasUrl ? url : null,
                          onClear: enabled
                              ? () {
                                  field.didChange(null);
                                  onChanged?.call(null);
                                }
                              : null,
                        )
                      : _EmptyWell(label: addLabel, enabled: enabled),
                ),
              ),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: Text(
                  field.errorText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _pick(FormFieldState<XFile?> field) async {
    final picked = await (pickImage ?? _defaultPick)();
    if (picked == null) return;
    field.didChange(picked);
    onChanged?.call(picked);
  }
}

Future<XFile?> _defaultPick() {
  return ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 95,
  );
}

class _EmptyWell extends StatelessWidget {
  const _EmptyWell({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurface.withValues(alpha: 0.38);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.file,
    required this.url,
    required this.onClear,
  });

  final XFile? file;
  final String? url;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (file != null)
          _FilePreview(file: file!)
        else
          AppNetworkImage(url: url!, fit: BoxFit.cover, decodeWidth: 900),
        if (onClear != null)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                tooltip: 'Buang',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: onClear,
              ),
            ),
          ),
      ],
    );
  }
}

class _FilePreview extends StatefulWidget {
  const _FilePreview({required this.file});

  final XFile file;

  @override
  State<_FilePreview> createState() => _FilePreviewState();
}

class _FilePreviewState extends State<_FilePreview> {
  late final Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          );
        }
        return Image.memory(snapshot.data!, fit: BoxFit.cover);
      },
    );
  }
}
