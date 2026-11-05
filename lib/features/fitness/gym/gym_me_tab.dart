import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/module_theme.dart';
import '../../../core/widgets/module_scaffold.dart';
import '../data/exercise_gif_cache.dart';
import '../data/fitness_media_settings.dart';
import '../data/fitness_offline_download.dart';
import '../data/fitness_repository.dart';
import '../domain/onboarding_profile.dart';
import '../workout_preferences_screen.dart';
import '../run_walk_screen.dart';
import '../yoga_screen.dart';

class GymMeTab extends ConsumerWidget {
  const GymMeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(workoutPreferencesProvider).valueOrNull;
    final measurements = ref.watch(measurementsProvider);
    final weightGrams = measurements.maybeWhen(
      data: (m) => m.isEmpty ? 0 : m.first.weightGrams,
      orElse: () => 0,
    );
    final height = prefs?.heightCm ?? 0;
    final bmi = OnboardingProfile.bmi(
      weightGrams: weightGrams,
      heightCm: height,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        96,
      ),
      children: [
        const ModuleHeader(
          title: 'Me',
          subtitle: 'Profile and extras',
          module: DashboardModule.fitness,
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.monitor_weight),
          title: Text(
            weightGrams > 0
                ? '${OnboardingProfile.gramsToKg(weightGrams).toStringAsFixed(1)} kg'
                : 'Weight not set',
          ),
          subtitle: Text(
            height > 0
                ? 'Height $height cm · BMI ${bmi.toStringAsFixed(1)} (${OnboardingProfile.bmiLabel(bmi)})'
                : 'Complete profile in settings',
          ),
        ),
        const _FitnessMediaSection(),
        ListTile(
          leading: const Icon(Icons.tune),
          title: const Text('Workout preferences'),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkoutPreferencesScreen(),
                ),
              ),
        ),
        ListTile(
          leading: const Icon(Icons.self_improvement),
          title: const Text('Yoga'),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const YogaScreen()),
              ),
        ),
        ListTile(
          leading: const Icon(Icons.directions_run),
          title: const Text('Run / Walk'),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RunWalkScreen()),
              ),
        ),
      ],
    );
  }
}

class _FitnessMediaSection extends ConsumerStatefulWidget {
  const _FitnessMediaSection();

  @override
  ConsumerState<_FitnessMediaSection> createState() =>
      _FitnessMediaSectionState();
}

class _FitnessMediaSectionState extends ConsumerState<_FitnessMediaSection> {
  var _downloading = false;

  Future<void> _setOnline(bool online) async {
    if (online) {
      await ref.read(fitnessMediaSettingsProvider.notifier).setOnline(true);
      return;
    }
    await ref.read(fitnessMediaSettingsProvider.notifier).setOnline(false);
    if (!mounted) return;
    final download = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Download for offline?'),
            content: const Text(
              'Download all workout GIFs and yoga images to this device? '
              'This may use significant storage and data.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Download'),
              ),
            ],
          ),
    );
    if (download == true && mounted) {
      await _startDownload();
    }
  }

  Future<void> _startDownload() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await runFitnessOfflineDownload(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline fitness pack saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(fitnessMediaSettingsProvider);
    final progress = ref.watch(gifDownloadProgressProvider);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fitness media',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Online')),
              ButtonSegment(value: false, label: Text('Offline')),
            ],
            selected: {media.online},
            onSelectionChanged: (s) => unawaited(_setOnline(s.first)),
          ),
          if (!media.online) ...[
            const SizedBox(height: 8),
            Text(
              media.offlinePackReady
                  ? 'Offline pack is on this device.'
                  : 'Media loads only from downloaded files.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!media.offlinePackReady || _downloading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.icon(
                  onPressed:
                      _downloading || progress != null ? null : _startDownload,
                  icon:
                      _downloading || progress != null
                          ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value:
                                  progress != null && progress.total > 0
                                      ? progress.done / progress.total
                                      : null,
                            ),
                          )
                          : const Icon(Icons.download_outlined),
                  label: Text(
                    progress != null
                        ? 'Downloading ${progress.done}/${progress.total}'
                        : 'Download workout & yoga pack',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
