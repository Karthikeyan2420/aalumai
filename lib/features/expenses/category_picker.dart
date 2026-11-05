import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import 'data/finance_repository.dart';

/// Category selection as chips, with add and long-press archive for custom ones.
class CategoryChipPicker extends ConsumerWidget {
  const CategoryChipPicker({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.kind,
    this.allowNone = true,
    this.noneLabel,
  });

  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final CategoryKind kind;
  final bool allowNone;
  final String? noneLabel;

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final repo = ref.read(financeRepositoryProvider);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var errorText = '';
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(l10n.newCategory),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.name,
                errorText: errorText.isEmpty ? null : errorText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    setState(() => errorText = l10n.required);
                    return;
                  }
                  if (await repo.categoryNameExists(name, kind)) {
                    setState(() => errorText = l10n.categoryExists);
                    return;
                  }
                  if (context.mounted) Navigator.pop(ctx, true);
                },
                child: Text(l10n.add),
              ),
            ],
          ),
        );
      },
    );
    if (saved != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    try {
      final id = await repo.createCategory(name, kind);
      onSelected(id);
    } on StateError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.categoryExists)),
        );
      }
    }
  }

  Future<void> _archiveCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    if (!category.isCustom) return;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.deleteConfirmTitle),
            content: Text(l10n.deleteConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
    if (ok != true) return;
    await ref.read(financeRepositoryProvider).archiveCategory(category.id);
    if (selectedId == category.id) onSelected(null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (allowNone)
          ChoiceChip(
            label: Text(noneLabel ?? l10n.none),
            selected: selectedId == null,
            onSelected: (_) => onSelected(null),
          ),
        for (final c in categories)
          GestureDetector(
            onLongPress:
                c.isCustom
                    ? () => _archiveCategory(context, ref, c)
                    : null,
            child: ChoiceChip(
              label: Text(c.name),
              selected: selectedId == c.id,
              onSelected: (_) => onSelected(c.id),
            ),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: Text(l10n.add),
          onPressed: () => _addCategory(context, ref),
        ),
      ],
    );
  }
}
