import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/providers/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

class _LanguageOption {
  const _LanguageOption(this.code, this.nativeName);
  final String code;
  final String nativeName;
}

/// The five supported interface languages, shown on the combined welcome screen.
const _languages = <_LanguageOption>[
  _LanguageOption('en', 'English'),
  _LanguageOption('ta', 'தமிழ்'),
  _LanguageOption('te', 'తెలుగు'),
  _LanguageOption('ml', 'മലയാളം'),
  _LanguageOption('kn', 'ಕನ್ನಡ'),
];

/// Combined first-run welcome screen: the branded AALUMAI experience (logo,
/// tagline, feature list) together with the language selector. It is shown once
/// as the first-run screen (via [onGetStarted]) and is also the `/landing`
/// route. [onGetStarted] is required when no router is available (the first-run
/// host swaps the widget out itself).
///
/// Uses the supplied full-screen `assets/images/landing.png` as a proportional
/// (cover) background and layers real widgets on top.
class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key, this.onGetStarted});

  /// Called after the language/first-run preferences are persisted. When `null`
  /// the screen navigates to the home route with go_router.
  final VoidCallback? onGetStarted;

  static const _backgroundAsset = 'assets/images/landing.png';
  static const _logoAsset = 'assets/images/logo.png';

  Future<void> _selectLanguage(WidgetRef ref, String code) async {
    await ref.read(localeCodeProvider.notifier).setLocale(code);
  }

  Future<void> _getStarted(BuildContext context, WidgetRef ref) async {
    await ref.read(appPreferencesProvider).setFirstRunComplete(true);
    if (onGetStarted != null) {
      onGetStarted!();
    } else if (context.mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final selectedLocale = ref.watch(localeCodeProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.navy),
          Image.asset(
            _backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          // Readability scrims: subtle darkening over the whole surface with a
          // stronger gradient behind the feature list and button.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x33000000),
                  Color(0xB3000000),
                ],
                stops: [0.0, 0.35, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 720;
                final verticalGap = compact ? 12.0 : 20.0;
                final featureSpacing = compact ? 10.0 : 14.0;
                final horizontalPadding =
                    constraints.maxWidth > 600 ? 32.0 : 20.0;
                final contentHeight =
                    constraints.maxHeight - (compact ? 32 : 48);

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: compact ? 16 : 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: contentHeight > 0 ? contentHeight : 0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _BrandingHeader(
                          l10n: l10n,
                          theme: theme,
                          verticalGap: verticalGap,
                          compact: compact,
                        ),
                        SizedBox(height: verticalGap),
                        _FeatureList(
                          l10n: l10n,
                          compact: compact,
                          spacing: featureSpacing,
                        ),
                        SizedBox(height: verticalGap),
                        _LanguageSelector(
                          l10n: l10n,
                          selected: selectedLocale,
                          onSelected: (code) => _selectLanguage(ref, code),
                        ),
                        SizedBox(height: verticalGap),
                        _GetStartedButton(
                          l10n: l10n,
                          onPressed: () => _getStarted(context, ref),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact language chooser shown on the welcome screen. Selecting a language
/// updates the app locale immediately and persists it through the settings
/// mechanism ([localeCodeProvider] → SharedPreferences).
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.l10n,
    required this.selected,
    required this.onSelected,
  });

  final AppLocalizations l10n;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l10n.chooseLanguage,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final lang in _languages)
                ChoiceChip(
                  key: ValueKey('landing_lang_${lang.code}'),
                  label: Text(lang.nativeName),
                  selected: selected == lang.code,
                  onSelected: (_) => onSelected(lang.code),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandingHeader extends StatelessWidget {
  const _BrandingHeader({
    required this.l10n,
    required this.theme,
    required this.verticalGap,
    required this.compact,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final double verticalGap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 64.0 : 84.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              LandingScreen._logoAsset,
              fit: BoxFit.contain,
              errorBuilder:
                  (_, __, ___) =>
                      const Icon(Icons.apps, size: 40, color: AppColors.navy),
            ),
          ),
        ),
        SizedBox(height: verticalGap),
        Text(
          l10n.landingBrandNative,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.landingBrandLatin,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.landingTaglineNative,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.landingTaglineEnglish,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({
    required this.l10n,
    required this.compact,
    required this.spacing,
  });

  final AppLocalizations l10n;
  final bool compact;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final items = <_FeatureItem>[
      _FeatureItem(
        icon: Icons.alarm,
        color: const Color(0xFF7C4DFF),
        title: l10n.featureSmartAlarms,
        subtitle: l10n.featureSmartAlarmsDesc,
      ),
      _FeatureItem(
        icon: Icons.fitness_center,
        color: const Color(0xFF00C853),
        title: l10n.featureFitness,
        subtitle: l10n.featureFitnessDesc,
      ),
      _FeatureItem(
        icon: Icons.music_note,
        color: const Color(0xFFFF4081),
        title: l10n.featureMusic,
        subtitle: l10n.featureMusicDesc,
      ),
      _FeatureItem(
        icon: Icons.check_circle,
        color: const Color(0xFFFF7043),
        title: l10n.featureHabits,
        subtitle: l10n.featureHabitsDesc,
      ),
      _FeatureItem(
        icon: Icons.savings,
        color: const Color(0xFF1E88E5),
        title: l10n.featureExpenses,
        subtitle: l10n.featureExpensesDesc,
      ),
      _FeatureItem(
        icon: Icons.calendar_month,
        color: const Color(0xFF00BFA5),
        title: l10n.featureCalendar,
        subtitle: l10n.featureCalendarDesc,
      ),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _FeatureRow(item: items[i], compact: compact),
            if (i < items.length - 1) SizedBox(height: spacing),
          ],
        ],
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.item, required this.compact});

  final _FeatureItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconSize = compact ? 38.0 : 42.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: iconSize + 12,
          height: iconSize + 12,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.icon, color: item.color, size: iconSize - 4),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.l10n, required this.onPressed});

  final AppLocalizations l10n;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          key: const ValueKey('landing_get_started'),
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E6FF6),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: const Color(0xFF1E6FF6).withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: Text(
            l10n.getStarted,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
