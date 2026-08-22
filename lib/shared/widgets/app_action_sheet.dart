import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Satu pilihan dalam [showAppActionSheet].
///
/// `value` ialah apa yang dipulangkan bila pilihan ditekan — biasanya
/// enum, supaya switch di pemanggil exhaustive.
class AppSheetAction<T> {
  const AppSheetAction({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
    this.isDestructive = false,
    this.isSelected = false,
    this.enabled = true,
  });

  final T value;
  final String label;

  /// Diabaikan di Cupertino — action sheet iOS tak guna ikon.
  final IconData? icon;

  /// Baris kedua yang lebih perlahan. Material sahaja.
  final String? subtitle;

  final bool isDestructive;

  /// Papar tanda semak — untuk sheet yang berfungsi sebagai pemilih
  /// (cth pilih role ahli), bukan senarai tindakan.
  final bool isSelected;

  final bool enabled;
}

/// Bottom sheet pilihan tindakan yang boleh guna semula.
///
/// Adaptive: `CupertinoActionSheet` di iOS/macOS, modal bottom sheet
/// Material di platform lain. Pulang `value` pilihan yang ditekan, atau
/// `null` bila ditutup tanpa pilih.
///
/// Contoh:
/// ```dart
/// final action = await showAppActionSheet<ContentAction>(
///   context,
///   title: 'Comment anda',
///   actions: const [
///     AppSheetAction(value: ContentAction.edit, label: 'Edit', icon: Icons.edit_outlined),
///     AppSheetAction(
///       value: ContentAction.delete,
///       label: 'Padam',
///       icon: Icons.delete_outline,
///       isDestructive: true,
///     ),
///   ],
/// );
/// ```
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppSheetAction<T>> actions,
  String cancelLabel = 'Batal',
}) {
  final platform = Theme.of(context).platform;
  final isApple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  if (isApple) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        message: message == null ? null : Text(message),
        actions: [
          for (final a in actions)
            CupertinoActionSheetAction(
              onPressed: a.enabled
                  ? () => Navigator.of(ctx).pop(a.value)
                  : () {},
              isDestructiveAction: a.isDestructive,
              isDefaultAction: a.isSelected,
              child: Text(a.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    // Handle diletak dalam DraggableScrollableSheet supaya leret
    // atas handle + senarai memandu saiz sheet yang sama.
    showDragHandle: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MaterialActionSheet<T>(
      title: title,
      message: message,
      actions: actions,
    ),
  );
}

/// Saiz [DraggableScrollableSheet] untuk action sheet Material.
///
/// Dua mode:
/// * **compact** — semua item muat di bawah [defaultInitial]; tinggi ikut
///   kandungan, tak boleh dileret naik.
/// * **scroll** — item lebih dari itu. Kalau lebih sikit (dalam slack 2
///   jubin), [initial] ikut kandungan. Kalau banyak, buka pada
///   [defaultInitial] dan boleh dileret ke [maxSize].
@visibleForTesting
class AppActionSheetMetrics {
  const AppActionSheetMetrics({
    required this.min,
    required this.initial,
    required this.max,
    required this.compact,
  });

  static const defaultInitial = 0.5;
  static const maxSize = 0.9;
  static const minSize = 0.22;

  static const tileHeight = 56.0;
  static const subtitleTileHeight = 72.0;
  static const handleHeight = 20.0;
  static const headerHeight = 48.0;
  static const footerHeight = 12.0;
  static const slackTiles = 2;

  final double min;
  final double initial;
  final double max;
  final bool compact;

  static AppActionSheetMetrics layout({
    required int actionCount,
    required bool hasHeader,
    required bool hasSubtitle,
    required double screenHeight,
    required double bottomInset,
  }) {
    final tile = hasSubtitle ? subtitleTileHeight : tileHeight;
    final contentHeight =
        handleHeight +
        (hasHeader ? headerHeight : 0) +
        actionCount * tile +
        footerHeight +
        bottomInset;
    final needed = (contentHeight / screenHeight).clamp(0.0, maxSize);
    final slack = slackTiles * tile / screenHeight;

    if (needed <= defaultInitial) {
      return AppActionSheetMetrics(
        min: needed,
        initial: needed,
        max: needed,
        compact: true,
      );
    }

    final initial = needed <= defaultInitial + slack ? needed : defaultInitial;
    return AppActionSheetMetrics(
      min: minSize,
      initial: initial,
      max: maxSize,
      compact: false,
    );
  }
}

class _MaterialActionSheet<T> extends StatelessWidget {
  const _MaterialActionSheet({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String? title;
  final String? message;
  final List<AppSheetAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final metrics = AppActionSheetMetrics.layout(
      actionCount: actions.length,
      hasHeader: title != null || message != null,
      hasSubtitle: actions.any((a) => a.subtitle != null),
      screenHeight: media.size.height,
      bottomInset: media.padding.bottom,
    );

    return DraggableScrollableSheet(
      expand: false,
      minChildSize: metrics.min,
      initialChildSize: metrics.initial,
      maxChildSize: metrics.max,
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) {
        return Material(
          color: scheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              if (title != null || message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (message != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          message!,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: actions.length,
                  itemBuilder: (context, i) {
                    final a = actions[i];
                    return ListTile(
                      enabled: a.enabled,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      leading: a.icon == null
                          ? null
                          : Icon(
                              a.icon,
                              color: a.isDestructive
                                  ? scheme.error
                                  : scheme.onSurface,
                            ),
                      title: Text(
                        a.label,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: a.isDestructive
                              ? scheme.error
                              : scheme.onSurface,
                        ),
                      ),
                      subtitle: a.subtitle == null
                          ? null
                          : Text(a.subtitle!),
                      trailing: a.isSelected
                          ? Icon(Icons.check, color: scheme.primary)
                          : null,
                      onTap: a.enabled
                          ? () => Navigator.of(context).pop(a.value)
                          : null,
                    );
                  },
                ),
              ),
              SizedBox(
                height:
                    AppActionSheetMetrics.footerHeight + media.padding.bottom,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppActionSheetMetrics.handleHeight,
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
