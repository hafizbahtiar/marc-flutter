import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marc/core/app_log.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/local_drafts_repository.dart';
import 'package:marc/shared/widgets/app_action_sheet.dart';
import 'package:marc/shared/widgets/app_dialog.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/image_grid_layout.dart';
import 'package:marc/shared/widgets/member_avatar.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';
import 'package:permission_handler/permission_handler.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

const _maxImagesPerPost = 4;
const _maxImageSizeBytes = 5 * 1024 * 1024;

/// Dimensi maksimum yang dinaikkan, dalam piksel (sisi panjang).
///
/// Kamera telefon keluarkan 3456x4608 ke atas. Kita TAK PERNAH papar pada
/// saiz tu - jubin grid feed lebih kurang separuh lebar skrin, dan pemapar
/// skrin penuh pun cuma perlukan piksel setinggi skrin darab faktor zum.
/// Menyimpan asal cuma membakar storan R2 dan kuota r2.dev.
///
/// 2048 dipilih supaya zum 4x pada skrin ~1080px lebar masih ada piksel
/// sebenar untuk dipaparkan, bukan hasil regangan.
const _maxUploadDimension = 2048.0;

/// Kualiti JPEG semasa re-encode. 95 sengaja tinggi - matlamatnya ialah
/// mengecilkan DIMENSI, bukan menghancurkan kualiti. Turun ke ~85 mula
/// nampak artifak pada gambar berbutir halus (teks, gradien).
const _uploadQuality = 95;

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _contentController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  final List<String> _uploadedKeys = [];
  bool _isAnnouncement = false;
  bool _submitting = false;
  bool _draftOnDisk = false;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final draft = await ref.read(draftRepositoryProvider).get(newPostDraftKey);
    if (draft == null || !mounted) return;
    _contentController.text = draft.content;
    setState(() {
      _isAnnouncement = draft.isAnnouncement ?? false;
      _draftOnDisk = true;
    });
  }

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
      final openSettings = await showAppDialog<bool>(
        context,
        title: 'Kebenaran galeri diperlukan',
        message:
            'MARC perlukan akses ke galeri untuk lampirkan gambar pada post. '
            'Sila benarkan akses dalam Tetapan.',
        actions: (ctx) => [
          AppDialogAction(
            label: 'Batal',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppDialogAction(
            label: 'Buka Tetapan',
            isPrimary: true,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      );
      if (openSettings ?? false) await openAppSettings();
      return false;
    }

    MySnackBar.error(context, 'Kebenaran galeri ditolak.');
    return false;
  }

  /// Ambil satu gambar guna kamera.
  ///
  /// Tiada semakan permission_handler di sini: pada Android, image_picker
  /// melancarkan app kamera sistem melalui intent, yang uruskan
  /// kebenarannya sendiri - mengisytiharkan CAMERA dalam manifest kita
  /// SEBALIKNYA akan memaksa permintaan runtime yang kita tak perlukan.
  /// Pada iOS, sistem yang minta, guna NSCameraUsageDescription.
  Future<void> _takePhoto() async {
    if (_images.length >= _maxImagesPerPost) {
      MySnackBar.error(
        context,
        'Maksimum $_maxImagesPerPost gambar setiap post.',
      );
      return;
    }

    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxUploadDimension,
      maxHeight: _maxUploadDimension,
      imageQuality: _uploadQuality,
    );
    if (shot == null || !mounted) return;

    if (await shot.length() > _maxImageSizeBytes) {
      if (mounted) {
        MySnackBar.error(context, 'Gambar melebihi had 5MB.');
      }
      return;
    }
    if (mounted) setState(() => _images.add(shot));
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

    // pickMultiImage(limit: 1) throws - kena guna pickImage() tunggal bila
    // baki slot cuma 1.
    // maxWidth/maxHeight buat image_picker mengecilkan gambar SEBELUM ia
    // sampai ke Dart - jadi kita tak pernah pegang bitmap penuh dalam
    // memori, dan bait yang dinaikkan pun dah kecil. `imageQuality`
    // sahaja TAK cukup: ia cuma kualiti re-encode JPEG, dimensi kekal.
    final picked = remaining == 1
        ? await _picker
              .pickImage(
                source: ImageSource.gallery,
                maxWidth: _maxUploadDimension,
                maxHeight: _maxUploadDimension,
                imageQuality: _uploadQuality,
              )
              .then((x) => x == null ? <XFile>[] : [x])
        : await _picker.pickMultiImage(
            maxWidth: _maxUploadDimension,
            maxHeight: _maxUploadDimension,
            imageQuality: _uploadQuality,
            limit: remaining,
          );
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
      appLog(
        'create_post',
        'mula (aksara=${content.length}, gambar=${_images.length}, '
            'dah_upload=${_uploadedKeys.length})',
      );
      // Retry-safe: kalau submit gagal separuh jalan lepas sesetengah
      // gambar dah berjaya upload, jangan re-upload gambar yang dah
      // berjaya tu bila user cuba "Hantar" semula - elak orphan R2
      // object bertambah setiap kali retry.
      while (_uploadedKeys.length < _images.length) {
        final index = _uploadedKeys.length;
        final key = await repo.uploadImage(_images[index]);
        _uploadedKeys.add(key);
        appLog(
          'create_post',
          'gambar ${index + 1}/${_images.length} siap upload',
        );
      }

      await repo.createPost(
        content: content,
        type: _isAnnouncement ? 'announcement' : 'normal',
        r2Keys: _uploadedKeys,
      );

      appLog('create_post', 'POST /posts berjaya');
      ref.invalidate(feedProvider);
      await ref.read(draftRepositoryProvider).delete(newPostDraftKey);
      if (!mounted) return;
      MySnackBar.success(context, 'Post dihantar.');
      context.pop();
    } on DioException catch (e) {
      appLogDioError('create_post', 'hantar post', e);
      if (!mounted) return;
      MySnackBar.error(context, extractErrorMessage(e));
    } catch (e, stack) {
      appLog('create_post', 'ralat bukan-Dio: $e\n$stack');
      if (!mounted) return;
      MySnackBar.error(context, 'Gagal hantar post. Cuba lagi.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _canSubmit =>
      _contentController.text.trim().isNotEmpty || _images.isNotEmpty;

  bool get _hasUnsavedContent =>
      _contentController.text.trim().isNotEmpty || _images.isNotEmpty;

  Future<void> _handlePopAttempt(bool didPop, Object? result) async {
    if (didPop) return;
    final choice = await _confirmExitWithDraft(
      context,
      hasImages: _images.isNotEmpty,
    );
    if (choice == null || !mounted) return;

    final repo = ref.read(draftRepositoryProvider);
    try {
      if (choice == _ExitDraftChoice.save) {
        await repo.save(
          newPostDraftKey,
          kind: 'post',
          content: _contentController.text.trim(),
          isAnnouncement: _isAnnouncement,
        );
        if (mounted) setState(() => _draftOnDisk = true);
      } else {
        await repo.delete(newPostDraftKey);
        if (mounted) setState(() => _draftOnDisk = false);
      }
    } catch (_) {
      // Draf ialah kemudahan best-effort - kegagalan storan tempatan
      // TIDAK sepatutnya memerangkap pengguna pada skrin ini.
      if (mounted) MySnackBar.error(context, 'Gagal simpan draf.');
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _removeImage(int i) {
    setState(() {
      _images.removeAt(i);
      // Kunci yang dah diupload sejajar dgn _images ikut indeks - buang
      // yang sepadan supaya retry tak melekatkan gambar yang salah.
      if (i < _uploadedKeys.length) _uploadedKeys.removeAt(i);
    });
  }

  Future<void> _deleteDraft() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Padam draf?',
      message:
          'Draf post ini akan dipadam dari peranti. Tindakan ini tidak '
          'boleh dibatalkan.',
      confirmLabel: 'Padam draf',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    try {
      await ref.read(draftRepositoryProvider).delete(newPostDraftKey);
      ref.invalidate(hasNewPostDraftProvider);
    } catch (_) {
      if (mounted) MySnackBar.error(context, 'Gagal padam draf.');
      return;
    }

    _contentController.clear();
    setState(() {
      _isAnnouncement = false;
      _draftOnDisk = false;
    });
    if (mounted) MySnackBar.success(context, 'Draf dipadam.');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final isManagement = profile?.isManagement ?? false;

    return PopScope(
      canPop: !_hasUnsavedContent,
      onPopInvokedWithResult: _handlePopAttempt,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Post baru'),
            // Garisan bawah dibuang: penggubah sepatutnya terasa seperti
            // satu helaian berterusan, bukan borang berkotak.
            scrolledUnderElevation: 0,
            actions: [
              if (_draftOnDisk)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Padam draf',
                  onPressed: _submitting ? null : _deleteDraft,
                ),
            ],
          ),
          bottomNavigationBar: _ComposerBar(
            imageCount: _images.length,
            maxImages: _maxImagesPerPost,
            submitting: _submitting,
            onPickImages: _images.length >= _maxImagesPerPost
                ? null
                : _pickImages,
            onTakePhoto: _images.length >= _maxImagesPerPost
                ? null
                : _takePhoto,
            onSubmit: (_submitting || !_canSubmit) ? null : _submit,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar penulis di sebelah penggubah - corak yang sama
                  // macam kad post, jadi mengarang terasa seperti melihat
                  // pratonton post kau sendiri.
                  MemberAvatar(
                    label: profile?.displayName ?? profile?.memberId ?? '?',
                    avatarUrl: profile?.avatarUrl,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isManagement) ...[
                          _AnnouncementChip(
                            value: _isAnnouncement,
                            onChanged: (v) =>
                                setState(() => _isAnnouncement = v),
                          ),
                          const SizedBox(height: 10),
                        ],
                        TextField(
                          controller: _contentController,
                          autofocus: true,
                          maxLines: null,
                          minLines: 3,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          // Butang hantar bergantung pada sama ada ada teks;
                          // tanpa ni ia kekal mati sampai rebuild lain.
                          onChanged: (_) => setState(() {}),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                height: 1.4,
                                fontWeight: FontWeight.w400,
                              ),
                          decoration: InputDecoration(
                            hintText: 'Apa yang berlaku?',
                            // filled: false MESTI eksplisit -
                            // inputDecorationTheme global set `filled: true`
                            // dgn surfaceContainerHighest, jadi `border:
                            // none` sahaja tinggalkan kotak kelabu. Penggubah
                            // patut duduk atas permukaan yang sama macam
                            // seluruh halaman.
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ),
                        if (_images.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          // Susun atur SAMA dengan feed - penulis nampak
                          // betul-betul rupa post nanti.
                          ImageGridLayout(
                            tiles: [
                              for (var i = 0; i < _images.length; i++)
                                _ImageThumb(
                                  image: _images[i],
                                  onRemove: () => _removeImage(i),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Toggle pengumuman sebagai pil, bukan SwitchListTile.
///
/// Padanan pemilih khalayak Twitter: ia sebahagian daripada penggubah,
/// bukan baris borang di atasnya. Keadaan aktif guna warna jenama supaya
/// jelas post ni akan kelihatan berbeza kepada semua ahli.
class _AnnouncementChip extends StatelessWidget {
  const _AnnouncementChip({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: value
            ? scheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  value ? Icons.campaign : Icons.campaign_outlined,
                  size: 16,
                  color: value ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  value ? 'Pengumuman' : 'Post biasa',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: value ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.expand_more,
                  size: 16,
                  color: value ? scheme.primary : scheme.onSurfaceVariant,
                ),
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
    required this.onTakePhoto,
    required this.onSubmit,
  });

  final int imageCount;
  final int maxImages;
  final bool submitting;
  final VoidCallback? onPickImages;
  final VoidCallback? onTakePhoto;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // bottomNavigationBar tak ikut viewInsets keyboard secara automatik
    // (lain dengan `body`) - kena tambah padding sendiri, guna paras
    // keyboard bila terbuka, fallback ke safe-area device (home
    // indicator) bila keyboard tertutup.
    final bottomInset = mediaQuery.viewInsets.bottom > 0
        ? mediaQuery.viewInsets.bottom
        : mediaQuery.padding.bottom;
    final scheme = Theme.of(context).colorScheme;

    // Tiada garisan pemisah: penggubah sepatutnya satu permukaan
    // berterusan dari medan teks sampai ke bar alat, bukan dua panel
    // berkotak.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.fromLTRB(8, 4, 12, 4 + bottomInset),
      child: Row(
        children: [
          // Galeri dan kamera berasingan, macam Twitter - menyorokkan
          // kamera di belakang satu ikon "media" menambah satu ketukan
          // pada tindakan yang paling kerap dibuat di telefon.
          IconButton(
            onPressed: submitting ? null : onPickImages,
            icon: const Icon(Icons.image_outlined),
            color: scheme.primary,
            tooltip: 'Pilih dari galeri',
          ),
          IconButton(
            onPressed: submitting ? null : onTakePhoto,
            icon: const Icon(Icons.photo_camera_outlined),
            color: scheme.primary,
            tooltip: 'Ambil gambar',
          ),
          // Kiraan hanya muncul selepas gambar pertama - "0/4" pada
          // penggubah kosong ialah bunyi bising.
          if (imageCount > 0)
            Text(
              '$imageCount/$maxImages',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: imageCount >= maxImages
                    ? scheme.error
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(
              // Pil, bukan segi empat lebar penuh: filledButtonTheme
              // global set minimumSize Size.fromHeight(54), iaitu LEBAR
              // TAK TERHINGGA - dalam Row ia meletup tanpa had eksplisit.
              minimumSize: const Size(84, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onSubmit,
            child: submitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
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
    // Isi jubin yang diberi ImageGridLayout, bukan segi empat tetap -
    // itu yang membuatkan pratonton padan dengan susunan feed sebenar.
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder<Uint8List>(
          future: _bytesFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              );
            }
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          },
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onRemove,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ExitDraftChoice { save, discard }

/// Sheet keluar gaya Twitter - tindakan simpan/buang gambar sengaja
/// diletak dalam mesej (bukan label pilihan): label mesti pendek (lihat
/// corak sedia ada showReasonDialog/showAppInputDialog). "Batal" ialah
/// cancelLabel lalai [showAppActionSheet] - leret bawah/ketik luar sheet
/// pun sama makna dengan Batal (pulang null).
Future<_ExitDraftChoice?> _confirmExitWithDraft(
  BuildContext context, {
  required bool hasImages,
}) {
  return showAppActionSheet<_ExitDraftChoice>(
    context,
    title: 'Simpan sebagai draf?',
    message: hasImages
        ? 'Anda ada kandungan belum dihantar. Gambar yang dipilih TIDAK '
              'disimpan dalam draf - pilih semula bila sambung nanti.'
        : 'Anda ada kandungan belum dihantar.',
    actions: const [
      AppSheetAction(
        value: _ExitDraftChoice.save,
        label: 'Simpan draf',
        icon: Icons.bookmark_add_outlined,
      ),
      AppSheetAction(
        value: _ExitDraftChoice.discard,
        label: 'Buang',
        icon: Icons.delete_outline,
        isDestructive: true,
      ),
    ],
  );
}
