import 'package:flutter/material.dart';

/// Pemegang seret untuk modal bottom sheet (action + form).
///
/// Saiz padan [AppActionSheetMetrics.handleHeight] supaya kiraan tinggi
/// action sheet tak terpesong.
class ModalSheetHandle extends StatelessWidget {
  const ModalSheetHandle({super.key});

  static const height = 20.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
          child: const SizedBox(width: 32, height: 4),
        ),
      ),
    );
  }
}
