import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/module_theme.dart';

/// 36px accent icon well used across module headers and list leading slots.
Widget moduleIconWell(
  BuildContext context, {
  required IconData icon,
  required Color accent,
  double size = 36,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: softTint(context, accent, 0.16),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: size * 0.55, color: accent),
  );
}

/// Standard in-module header row (sentence-case title, subtitle, trailing actions).
class ModuleHeader extends StatelessWidget {
  const ModuleHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.module,
    this.accent,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final DashboardModule? module;
  final Color? accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moduleColor = accent ?? module?.accent;
    final leadingIcon = icon ?? module?.icon;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leadingIcon != null && moduleColor != null) ...[
            moduleIconWell(
              context,
              icon: leadingIcon,
              accent: moduleColor,
            ),
            const SizedBox(width: 12),
          ] else if (moduleColor != null) ...[
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: moduleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Full module page: optional app bar tint, body, FAB.
class ModulePage extends StatelessWidget {
  const ModulePage({
    super.key,
    required this.title,
    this.subtitle,
    this.module,
    this.accent,
    this.icon,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.appBarTint = false,
  });

  final String title;
  final String? subtitle;
  final DashboardModule? module;
  final Color? accent;
  final IconData? icon;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool appBarTint;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? module?.accent;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        backgroundColor:
            appBarTint && color != null
                ? softTint(context, color, 0.08)
                : null,
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

/// Scrollable module body with consistent horizontal padding.
class ModuleScrollBody extends StatelessWidget {
  const ModuleScrollBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.screen,
      8,
      AppSpacing.screen,
      96,
    ),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: children,
    );
  }
}

/// Tappable list row with card surface — shared by tasks, notes, events, alarms.
class ModuleListTile extends StatelessWidget {
  const ModuleListTile({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(child: child),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal filter chips with animated selection styling.
class ModuleFilterBar extends StatelessWidget {
  const ModuleFilterBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: FilterChip(
              label: Text(labels[index]),
              selected: selected,
              onSelected: (_) => onSelected(index),
              showCheckmark: false,
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                color:
                    selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
              ),
              side: BorderSide(
                color:
                    selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : theme.colorScheme.outlineVariant,
              ),
              backgroundColor: theme.colorScheme.surface,
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.14),
            ),
          );
        },
      ),
    );
  }
}

/// Accent color for a feature module (use on buttons, rings, nav indicator).
Color moduleAccent(BuildContext context, DashboardModule module) =>
    module.accent;

Color fitnessAccent(BuildContext context) =>
    Theme.of(context).colorScheme.primary;
