import 'package:flutter/material.dart';

/// Tag kecil "Disunting" pada post/comment yang pernah diedit.
///
/// Dulu ia cuma teks "· disunting" yang senang hilang antara nama dan
/// masa. Sekarang satu pill supaya jelas ia label, bukan sebahagian
/// teks masa. Dikongsi antara PostCard dan comment tile supaya dua-dua
/// kekal sama rupa.
class EditedBadge extends StatelessWidget {
  const EditedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Disunting',
        style: TextStyle(
          fontSize: 10,
          height: 1.4,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
