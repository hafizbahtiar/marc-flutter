import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

const _qrAsset = 'assets/donation/maybank_hafiz.jpeg';

/// DuitNow QR peribadi — jalan sokongan tanpa yuran.
///
/// Kenapa ia wujud di sebelah Stripe: **Stripe tak menyokong DuitNow
/// langsung** (Malaysia dapat FPX, GrabPay dan kad sahaja — dan FPX pun
/// perlukan BRN/SSM yang kita belum ada), sedangkan
/// DuitNow ialah cara paling biasa orang Malaysia hantar duit sesama
/// sendiri. Gateway tempatan yang menyokong DuitNow QR (Billplz) perlukan
/// akaun syarikat, jadi QR peribadi ialah satu-satunya laluan yang tinggal.
///
/// Tukar ganti yang MESTI dinyatakan kepada pengguna: bayaran QR TIDAK
/// melalui backend kita, jadi tiada baris `donations`, tiada resit PDF,
/// tiada emel. Membiarkan orang menyangka mereka akan dapat resit ialah
/// cara paling mudah hilang kepercayaan.
class DuitNowQrCard extends StatefulWidget {
  const DuitNowQrCard({super.key});

  @override
  State<DuitNowQrCard> createState() => _DuitNowQrCardState();
}

class _DuitNowQrCardState extends State<DuitNowQrCard> {
  bool _saving = false;

  Future<void> _saveToGallery() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // Gal uruskan kebenaran galeri untuk kedua-dua platform, termasuk
      // storan berskop Android 13+ (tiada WRITE_EXTERNAL_STORAGE).
      if (!await Gal.hasAccess(toAlbum: true)) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (mounted) {
            MySnackBar.error(context, 'Kebenaran galeri diperlukan.');
          }
          return;
        }
      }

      final bytes = await rootBundle.load(_qrAsset);
      await Gal.putImageBytes(
        bytes.buffer.asUint8List(),
        name: 'MARC-DuitNow-QR',
      );
      if (mounted) {
        MySnackBar.success(context, 'QR disimpan ke galeri.');
      }
    } on GalException catch (e) {
      if (mounted) {
        MySnackBar.error(context, 'Gagal simpan QR: ${e.type.message}');
      }
    } catch (_) {
      if (mounted) {
        MySnackBar.error(context, 'Gagal simpan QR.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'DuitNow QR',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Imbas guna mana-mana app bank atau e-wallet. Tiada yuran '
            'pemprosesan - sumbangan sampai penuh.',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              // QR tak perlu besar untuk boleh diimbas, dan membiarkannya
              // mengembang penuh menolak butang "Simpan" keluar skrin.
              constraints: const BoxConstraints(maxWidth: 260),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  _qrAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'QR tidak dapat dimuat.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _saving ? null : _saveToGallery,
            icon: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined, size: 18),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan QR ke galeri'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Perbezaan ni MESTI dinyatakan — pengguna yang menjangka resit
          // dan tak menerimanya akan fikir sumbangan mereka hilang.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sumbangan melalui QR tidak direkodkan dalam app, jadi '
                  'tiada resit automatik. Kalau anda perlukan resit, guna '
                  'kad di bawah.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
