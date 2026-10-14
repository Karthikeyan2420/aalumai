import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/router/app_router.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = <_MoreItem>[
      _MoreItem(Icons.payments_outlined, l10n.expenses, AppRoutes.expenses),
      _MoreItem(Icons.savings_outlined, l10n.savingsGoals, AppRoutes.savings),
      _MoreItem(Icons.restaurant_outlined, l10n.meals, AppRoutes.meals),
      _MoreItem(Icons.check_circle_outline, l10n.habits, AppRoutes.habits),
      _MoreItem(
        Icons.menu_book_outlined,
        l10n.learnEnglish,
        AppRoutes.learning,
      ),
      _MoreItem(Icons.alarm, l10n.alarms, AppRoutes.alarms),
      _MoreItem(Icons.library_music_outlined, l10n.music, AppRoutes.music),
      _MoreItem(Icons.edit_note, l10n.notes, AppRoutes.notes),
      _MoreItem(Icons.settings_outlined, l10n.settings, AppRoutes.settings),
      _MoreItem(Icons.info_outline, l10n.about, AppRoutes.about),
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
  const _MoreItem(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
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
        onTap: () => context.go(item.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 30, color: theme.colorScheme.secondary),
              const Spacer(),
              Text(
                item.label,
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
