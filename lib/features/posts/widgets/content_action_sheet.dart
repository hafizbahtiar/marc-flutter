import 'package:flutter/material.dart';
import 'package:marc/shared/ui/sheet/app_action_sheet.dart';

/// Tindakan pada satu keping kandungan (post atau comment).
enum ContentAction { edit, delete }

/// Sheet "Edit / Padam" yang dikongsi post dan comment.
///
/// Post dan comment ada peraturan keizinan yang SAMA (pemilik boleh edit;
/// pemilik atau management boleh padam), jadi satu pembungkus di sini
/// menghalang label dan susunan dua-dua tempat itu terpesong.
///
/// Pulang `null` bila ditutup tanpa pilih, atau bila tiada satu pun
/// tindakan dibenarkan (sheet kosong tak dipapar langsung).
Future<ContentAction?> showContentActionSheet(
  BuildContext context, {
  required String title,
  required bool canEdit,
  required bool canDelete,
}) {
  final actions = <AppSheetAction<ContentAction>>[
    if (canEdit)
      const AppSheetAction(
        value: ContentAction.edit,
        label: 'Edit',
        icon: Icons.edit_outlined,
      ),
    if (canDelete)
      const AppSheetAction(
        value: ContentAction.delete,
        label: 'Padam',
        icon: Icons.delete_outline,
        isDestructive: true,
      ),
  ];

  if (actions.isEmpty) return Future.value(null);

  return showAppActionSheet<ContentAction>(
    context,
    title: title,
    actions: actions,
  );
}
