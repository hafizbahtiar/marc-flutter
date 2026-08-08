import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';
import 'package:permission_handler/permission_handler.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

const _maxImagesPerPost = 4;
const _maxImageSizeBytes = 5 * 1024 * 1024;

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _contentController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  final List<String> _uploadedKeys = [];
  bool _isAnnouncement = false;
  bool _submitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // Permission.photos merangkumi READ_MEDIA_IMAGES (Android 13+) dan
  // Photos (iOS); pada Android <13 permission_handler pulangkan granted
  // terus sebab READ_MEDIA_IMAGES tak wujud pada versi tu.
  Future<bool> _ensurePhotoPermission() async {
    final status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) return true;
    if (!mounted) return false;

    if (status.isPermanentlyDenied) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kebenaran galeri diperlukan'),
          content: const Text(
            'MARC perlukan akses ke galeri untuk lampirkan gambar pada post. '
            'Sila benarkan akses dalam Tetapan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Buka Tetapan'),
            ),
          ],
        ),
      );
      if (openSettings ?? false) await openAppSettings();
      return false;
    }

    MySnackBar.error(context, 'Kebenaran galeri ditolak.');
    return false;
  }

  Future<void> _pickImages() async {
    final remaining = _maxImagesPerPost - _images.length;
    if (remaining <= 0) {
      MySnackBar.error(
        context,
        'Maksimum $_maxImagesPerPost gambar setiap post.',
      );
      return;
    }

    if (!await _ensurePhotoPermission()) return;
    if (!mounted) return;

    // pickMultiImage(limit: 1) throws — kena guna pickImage() tunggal bila
    // baki slot cuma 1.
    final picked = remaining == 1
        ? await _picker
              .pickImage(source: ImageSource.gallery, imageQuality: 85)
              .then((x) => x == null ? <XFile>[] : [x])
        : await _picker.pickMultiImage(imageQuality: 85, limit: remaining);
    if (picked.isEmpty) return;

    final accepted = <XFile>[];
    var rejectedTooLarge = false;
    for (final image in picked.take(remaining)) {
      final size = await image.length();
      if (size > _maxImageSizeBytes) {
        rejectedTooLarge = true;
        continue;
      }
      accepted.add(image);
    }

    if (!mounted) return;
    if (accepted.isNotEmpty) setState(() => _images.addAll(accepted));
    if (rejectedTooLarge) {
      MySnackBar.error(
        context,
        'Sesetengah gambar melebihi had 5MB dan diabaikan.',
      );
    }
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _images.isEmpty) {
      MySnackBar.error(context, 'Tulis sesuatu atau lampirkan gambar dahulu.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(postRepositoryProvider);
      // Retry-safe: kalau submit gagal separuh jalan lepas sesetengah
      // gambar dah berjaya upload, jangan re-upload gambar yang dah
      // berjaya tu bila user cuba "Hantar" semula — elak orphan R2
      // object bertambah setiap kali retry.
      while (_uploadedKeys.length < _images.length) {
        final key = await repo.uploadImage(_images[_uploadedKeys.length]);
        _uploadedKeys.add(key);
      }

      await repo.createPost(
        content: content,
        type: _isAnnouncement ? 'announcement' : 'normal',
        r2Keys: _uploadedKeys,
      );

      ref.invalidate(feedProvider);
      if (!mounted) return;
      MySnackBar.success(context, 'Post dihantar.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      MySnackBar.error(
        context,
        e is DioException
            ? extractErrorMessage(e)
            : 'Gagal hantar post. Cuba lagi.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManagement =
        ref.watch(myProfileProvider).valueOrNull?.isManagement ?? false;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Post baru')),
        bottomNavigationBar: _ComposerBar(
          imageCount: _images.length,
          maxImages: _maxImagesPerPost,
          submitting: _submitting,
          onPickImages: _images.length >= _maxImagesPerPost
              ? null
              : _pickImages,
          onSubmit: _submitting ? null : _submit,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isManagement)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Jadikan Pengumuman'),
                    subtitle: const Text(
                      'Semua ahli akan nampak label "Pengumuman"',
                    ),
                    value: _isAnnouncement,
                    onChanged: (v) => setState(() => _isAnnouncement = v),
                  ),
                TextField(
                  controller: _contentController,
                  maxLines: 8,
                  minLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Apa yang berlaku?',
                    border: InputBorder.none,
                  ),
                ),
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => _ImageThumb(
                        image: _images[i],
                        onRemove: () => setState(() {
                          _images.removeAt(i);
                          if (i < _uploadedKeys.length) {
                            _uploadedKeys.removeAt(i);
                          }
                        }),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.imageCount,
    required this.maxImages,
    required this.submitting,
    required this.onPickImages,
    required this.onSubmit,
  });

  final int imageCount;
  final int maxImages;
  final bool submitting;
  final VoidCallback? onPickImages;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // bottomNavigationBar tak ikut viewInsets keyboard secara automatik
    // (lain dengan `body`) — kena tambah padding sendiri, guna paras
    // keyboard bila terbuka, fallback ke safe-area device (home
    // indicator) bila keyboard tertutup.
    final bottomInset = mediaQuery.viewInsets.bottom > 0
        ? mediaQuery.viewInsets.bottom
        : mediaQuery.padding.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: EdgeInsets.fromLTRB(12, 1, 12, 1 + bottomInset),
      child: Row(
        children: [
          IconButton(
            onPressed: submitting ? null : onPickImages,
            icon: const Icon(Icons.image_outlined),
          ),
          Text(
            '$imageCount/$maxImages',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: onSubmit,
            child: submitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator.adaptive(),
                  )
                : const Text('Hantar'),
          ),
        ],
      ),
    );
  }
}

class _ImageThumb extends StatefulWidget {
  const _ImageThumb({required this.image, required this.onRemove});

  final XFile image;
  final VoidCallback onRemove;

  @override
  State<_ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<_ImageThumb> {
  late final Future<Uint8List> _bytesFuture = widget.image.readAsBytes();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: FutureBuilder<Uint8List>(
            future: _bytesFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  width: 90,
                  height: 90,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                );
              }
              return Image.memory(
                snapshot.data!,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: widget.onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
