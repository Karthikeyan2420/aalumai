import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/permissions/app_permissions.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/module_theme.dart';
import '../../core/widgets/dashboard_components.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final permissions = ref.watch(featurePermissionsProvider);

    List<_MoreItem> visible(List<_MoreItem> items) =>
        items
            .where(
              (item) =>
                  item.feature == null || permissions.isVisible(item.feature!),
            )
            .toList();

    final life = visible([
      _MoreItem(
        AppFeature.lifeSchedule,
        Icons.calendar_month_outlined,
        l10n.navSchedule,
        AppRoutes.schedule,
        ModuleAccents.schedule,
      ),
      _MoreItem(
        AppFeature.lifeNotes,
        Icons.edit_note,
        l10n.notes,
        AppRoutes.notes,
        ModuleAccents.notes,
      ),
      _MoreItem(
        AppFeature.lifeAlarms,
        Icons.alarm,
        l10n.alarms,
        AppRoutes.alarms,
        ModuleAccents.alarm,
      ),
      _MoreItem(
        AppFeature.lifeHabits,
        Icons.check_circle_outline,
        l10n.habits,
        AppRoutes.habits,
        ModuleAccents.habits,
      ),
    ]);
    final wellness = visible([
      _MoreItem(
        AppFeature.wellnessMusic,
        Icons.library_music_outlined,
        l10n.music,
        AppRoutes.music,
        ModuleAccents.music,
      ),
    ]);

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
          if (life.isNotEmpty) ...[
            _MoreGroup(title: l10n.moreGroupLife, items: life),
            const SizedBox(height: AppSpacing.cardGap),
          ],
          if (wellness.isNotEmpty) ...[
            _MoreGroup(title: l10n.moreGroupWellness, items: wellness),
            const SizedBox(height: AppSpacing.cardGap),
          ],
          _MoreGroup(
            title: l10n.moreGroupApp,
            items: [
              _MoreItem(
                null,
                Icons.settings_outlined,
                l10n.settings,
                AppRoutes.settings,
                ModuleAccents.settings,
              ),
              _MoreItem(
                null,
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
  const _MoreItem(this.feature, this.icon, this.label, this.route, this.accent);
  final AppFeature? feature;
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
