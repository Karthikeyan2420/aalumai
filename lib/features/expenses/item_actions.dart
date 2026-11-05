import 'package:flutter/material.dart';

import '../../core/localization/l10n_extension.dart';

Future<void> showEditDeleteMenu(
  BuildContext context, {
  required VoidCallback onEdit,
  required Future<void> Function() onDelete,
}) async {
  final l10n = context.l10n;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.edit),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.delete),
                onTap: () async {
                  Navigator.pop(ctx);
                  await onDelete();
                },
              ),
            ],
          ),
        ),
  );
}

Widget itemMoreButton({
  required VoidCallback onPressed,
}) {
  return IconButton(
    icon: const Icon(Icons.more_vert),
    onPressed: onPressed,
  );
}
