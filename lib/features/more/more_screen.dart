import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/module_theme.dart';
import '../../core/widgets/dashboard_components.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          8,
          AppSpacing.screen,
          32,
        ),
        children: [
          _MoreGroup(
            title: l10n.moreGroupLife,
            items: [
              _MoreItem(
                Icons.calendar_month_outlined,
                l10n.navSchedule,
                AppRoutes.schedule,
                ModuleAccents.schedule,
              ),
              _MoreItem(
                Icons.edit_note,
                l10n.notes,
                AppRoutes.notes,
                ModuleAccents.notes,
              ),
              _MoreItem(
                Icons.alarm,
                l10n.alarms,
                AppRoutes.alarms,
                ModuleAccents.alarm,
              ),
              _MoreItem(
                Icons.check_circle_outline,
                l10n.habits,
                AppRoutes.habits,
                ModuleAccents.habits,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.cardGap),
          _MoreGroup(
            title: l10n.moreGroupWellness,
            items: [
              _MoreItem(
                Icons.library_music_outlined,
                l10n.music,
                AppRoutes.music,
                ModuleAccents.music,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.cardGap),
          _MoreGroup(
            title: l10n.moreGroupApp,
            items: [
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
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreGroup extends StatelessWidget {
  const _MoreGroup({required this.title, required this.items});

  final String title;
  final List<_MoreItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 560 ? 3 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.cardGap,
              mainAxisSpacing: AppSpacing.cardGap,
              childAspectRatio: 1.35,
              children: [for (final item in items) _MoreTile(item: item)],
            );
          },
        ),
      ],
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
    return AppCard(
      onTap: () => context.push(item.route),
      padding: const EdgeInsets.all(14),
      semanticLabel: item.label,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: softTint(context, item.accent, 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 20, color: item.accent),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
          Text(
            item.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
