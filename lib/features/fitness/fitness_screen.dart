import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/module_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dashboard_components.dart';
import 'data/fitness_repository.dart';
import 'gym/gym_daily_plan_tabs.dart';
import 'gym/gym_me_tab.dart';
import 'gym/gym_onboarding_flow.dart';
import 'gym/gym_workout_tab.dart';

/// Gym-style fitness module: Daily, Plan, Workout, Me.
class FitnessScreen extends ConsumerStatefulWidget {
  const FitnessScreen({super.key});

  @override
  ConsumerState<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends ConsumerState<FitnessScreen> {
  var _index = 0;
  var _showOnboarding = false;

  static const _labels = ['Daily', '30 Plan', 'Workout', 'Me'];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prefsAsync = ref.watch(workoutPreferencesProvider);
    if (prefsAsync.isLoading) {
      return const Scaffold(body: LoadingState());
    }
    if (_showOnboarding || prefsAsync.valueOrNull?.onboardingDone != true) {
      return GymOnboardingFlow(
        onComplete: () => setState(() => _showOnboarding = false),
      );
    }
    final accent = ModuleAccents.fitness;
    final theme = Theme.of(context);
    final tabs = [
      const GymDailyTab(),
      const GymPlanTab(),
      const GymWorkoutTab(),
      const GymMeTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navFitness),
        backgroundColor: softTint(context, accent, 0.08),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeeklySummaryBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              8,
              AppSpacing.screen,
              8,
            ),
            child: SegmentedButton<int>(
              segments: [
                for (var i = 0; i < _labels.length; i++)
                  ButtonSegment(value: i, label: Text(_labels[i])),
              ],
              selected: {_index},
              onSelectionChanged: (s) => setState(() => _index = s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: WidgetStatePropertyAll(
                  BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey(_index),
                child: tabs[_index],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySummaryBanner extends ConsumerWidget {
  const _WeeklySummaryBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final weekly = ref.watch(weeklyActivityProvider);
    final water = ref.watch(waterTodayProvider).valueOrNull ?? const [];
    final waterMl = water.fold<int>(0, (s, w) => s + w.amountMl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        8,
        AppSpacing.screen,
        0,
      ),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.insights, color: ModuleAccents.fitness),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${l10n.weeklySummary}: '
                '${weekly.workouts} ${l10n.workouts.toLowerCase()}, '
                '${(weekly.distanceMeters / 1000).toStringAsFixed(1)} km, '
                '$waterMl ml ${l10n.water.toLowerCase()}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
