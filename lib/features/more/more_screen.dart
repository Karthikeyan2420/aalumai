import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/module_theme.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = <_MoreItem>[
      _MoreItem(
        Icons.payments_outlined,
        l10n.expenses,
        AppRoutes.expenses,
        ModuleAccents.expenses,
      ),
      _MoreItem(
        Icons.savings_outlined,
        l10n.savingsGoals,
        AppRoutes.savings,
        ModuleAccents.savings,
      ),
      _MoreItem(
        Icons.restaurant_outlined,
        l10n.meals,
        AppRoutes.meals,
        ModuleAccents.meals,
      ),
      _MoreItem(
        Icons.check_circle_outline,
        l10n.habits,
        AppRoutes.habits,
        ModuleAccents.habits,
      ),
      _MoreItem(
        Icons.menu_book_outlined,
        l10n.learnEnglish,
        AppRoutes.learning,
        ModuleAccents.learning,
      ),
      _MoreItem(
        Icons.alarm,
        l10n.alarms,
        AppRoutes.alarms,
        ModuleAccents.alarm,
      ),
      _MoreItem(
        Icons.library_music_outlined,
        l10n.music,
        AppRoutes.music,
        ModuleAccents.music,
      ),
      _MoreItem(
        Icons.edit_note,
        l10n.notes,
        AppRoutes.notes,
        ModuleAccents.notes,
      ),
      _MoreItem(
        Icons.settings_outlined,
        l10n.settings,
        AppRoutes.settings,
        ModuleAccents.settings,
      ),
      _MoreItem(
        Icons.info_outline,
        l10n.about,
        AppRoutes.about,
        ModuleAccents.blue,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(12),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [for (final item in items) _MoreTile(item: item)],
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem(this.icon, this.label, this.route, this.accent);
  final IconData icon;
  final String label;
  final String route;
  final Color accent;
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.item});
  final _MoreItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(item.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: softTint(context, item.accent, 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 21, color: item.accent),
              ),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
