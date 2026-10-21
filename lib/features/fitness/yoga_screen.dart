import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/fitness_repository.dart';
import 'data/yoga_repository.dart';
import 'domain/indian_yoga.dart';
import 'domain/yoga.dart';
import 'widgets/yoga_labels.dart';
import 'widgets/yoga_pose_image.dart';
import 'yoga_history_screen.dart';
import 'yoga_player_screen.dart';

/// The dedicated yoga section: a recommended practice for today, the full set
/// of routines, and the pose library with categories, search and favourites.
///
/// Practice content is informed by the Ministry of AYUSH *Common Yoga Protocol*
/// concept but is not government-approved, not AYUSH-certified, and not medical
/// advice. Numbers, durations and instructions stay editable by design.
class YogaScreen extends ConsumerStatefulWidget {
  const YogaScreen({super.key});

  @override
  ConsumerState<YogaScreen> createState() => _YogaScreenState();
}

class _YogaScreenState extends ConsumerState<YogaScreen> {
  YogaDifficulty? _difficulty;
  String _query = '';
  String? _category;
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prefs = ref.watch(workoutPreferencesProvider).valueOrNull;
    final difficulty =
        _difficulty ??
        yogaDifficultyFromLevelIndex(prefs?.fitnessLevel.index ?? 0);
    final posesAsync = ref.watch(yogaPosesProvider);
    final favorites = ref.watch(yogaFavoritesProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.yoga),
        actions: [
          IconButton(
            tooltip: l10n.yogaHistory,
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const YogaHistoryScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.yogaSync,
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () => _sync(),
          ),
        ],
      ),
      body: posesAsync.when(
        loading: () => const LoadingState(),
        error:
            (e, _) => ErrorState(
              message: e.toString(),
              onRetry: () => ref.invalidate(yogaPosesProvider),
            ),
        data:
            (poses) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _difficultySelector(difficulty),
                const SizedBox(height: 12),
                _todayCard(poses, difficulty),
                const SizedBox(height: 24),
                _sectionTitle(l10n.yogaRoutines),
                for (final kind in YogaRoutineKind.values)
                  _routineCard(poses, kind, difficulty),
                const SizedBox(height: 24),
                _sectionTitle(l10n.yogaPoses),
                _poseFilters(poses, favorites),
                const SizedBox(height: 8),
                ..._poseTiles(poses, favorites),
                const SizedBox(height: 16),
                Text(
                  l10n.yogaAttribution,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  Widget _difficultySelector(YogaDifficulty difficulty) {
    final l10n = context.l10n;
    return Row(
      children: [
        Text('${l10n.yogaLevel}: ', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 8),
        Expanded(
          child: SegmentedButton<YogaDifficulty>(
            showSelectedIcon: false,
            segments: [
              for (final level in YogaDifficulty.values)
                ButtonSegment(
                  value: level,
                  label: Text(yogaDifficultyLabel(l10n, level)),
                ),
            ],
            selected: {difficulty},
            onSelectionChanged:
                (value) => setState(() => _difficulty = value.first),
          ),
        ),
      ],
    );
  }

  Widget _todayCard(List<YogaPose> poses, YogaDifficulty difficulty) {
    final l10n = context.l10n;
    final kind = dailyYogaRecommendation(DateTime.now().weekday);
    final routine = YogaRoutineGenerator.build(
      kind: kind,
      difficulty: difficulty,
      poses: poses,
    );
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.self_improvement, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.yogaToday,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              kind.label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              kind.summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.yogaMinutes(routine.totalMinutes)} · '
              '${l10n.yogaPoseCount(routine.poseCount)}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  routine.isNotEmpty ? () => _startRoutine(routine) : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.yogaStartRoutine),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routineCard(
    List<YogaPose> poses,
    YogaRoutineKind kind,
    YogaDifficulty difficulty,
  ) {
    final l10n = context.l10n;
    final routine = YogaRoutineGenerator.build(
      kind: kind,
      difficulty: difficulty,
      poses: poses,
    );
    return Card(
      child: ListTile(
        leading: const Icon(Icons.self_improvement),
        title: Text(kind.label),
        subtitle: Text(
          '${kind.summary}\n'
          '${l10n.yogaMinutes(routine.totalMinutes)} · '
          '${l10n.yogaPoseCount(routine.poseCount)}',
        ),
        isThreeLine: true,
        trailing: TextButton(
          onPressed: routine.isNotEmpty ? () => _startRoutine(routine) : null,
          child: Text(l10n.yogaStart),
        ),
      ),
    );
  }

  Widget _poseFilters(List<YogaPose> poses, Set<String> favorites) {
    final l10n = context.l10n;
    final categories = <String>{
      for (final pose in poses)
        pose.category.isEmpty ? l10n.yogaCategoryOther : pose.category,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.yogaSearchPoses,
            isDense: true,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(l10n.yogaFavorites),
                avatar: const Icon(Icons.favorite, size: 18),
                selected: _favoritesOnly,
                onSelected:
                    (value) => setState(() => _favoritesOnly = value),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(l10n.yogaAllCategories),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected:
                      (_) => setState(
                        () =>
                            _category = _category == category ? null : category,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _poseTiles(List<YogaPose> poses, Set<String> favorites) {
    final l10n = context.l10n;
    final query = _query.trim().toLowerCase();
    final filtered =
        poses.where((pose) {
          if (_favoritesOnly && !favorites.contains(pose.key)) return false;
          if (_category != null) {
            final category =
                pose.category.isEmpty ? l10n.yogaCategoryOther : pose.category;
            if (category != _category) return false;
          }
          if (query.isEmpty) return true;
          return pose.englishName.toLowerCase().contains(query) ||
              pose.sanskritName.toLowerCase().contains(query);
        }).toList();

    if (filtered.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            _favoritesOnly ? l10n.yogaNoFavorites : l10n.yogaNoResults,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }

    return [
      for (final pose in filtered)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: YogaPoseImage(imageUrl: pose.imageUrl, size: 52),
            title: Text(pose.englishName),
            subtitle:
                pose.sanskritName.isEmpty ? null : Text(pose.sanskritName),
            trailing: IconButton(
              icon: Icon(
                favorites.contains(pose.key)
                    ? Icons.favorite
                    : Icons.favorite_border,
              ),
              color:
                  favorites.contains(pose.key)
                      ? Theme.of(context).colorScheme.error
                      : null,
              tooltip:
                  favorites.contains(pose.key)
                      ? l10n.yogaRemoveFavorite
                      : l10n.yogaAddFavorite,
              onPressed:
                  () => ref
                      .read(yogaRepositoryProvider)
                      .toggleFavorite(pose.key),
            ),
            onTap: () => _showPoseDetail(pose, favorites),
          ),
        ),
    ];
  }

  Future<void> _startRoutine(YogaRoutine routine) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => YogaPlayerScreen(routine: routine),
      ),
    );
  }

  Future<void> _sync() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await ref.read(yogaApiSyncProvider)();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.yogaSynced(count))),
      );
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.yogaSyncFailed)));
    }
  }

  void _showPoseDetail(YogaPose pose, Set<String> favorites) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            builder:
                (context, controller) => _PoseDetail(
                  pose: pose,
                  isFavorite: favorites.contains(pose.key),
                  scrollController: controller,
                ),
          ),
    );
  }
}

/// Full pose detail as a bottom sheet: image (or written placeholder),
/// description, benefits, instructions, breathing and safety notes.
class _PoseDetail extends ConsumerWidget {
  const _PoseDetail({
    required this.pose,
    required this.isFavorite,
    required this.scrollController,
  });

  final YogaPose pose;
  final bool isFavorite;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Center(
          child: YogaPoseImage(
            imageUrl: pose.imageUrl,
            size: 200,
            borderRadius: 24,
            noImageLabel: l10n.yogaNoImage,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          pose.englishName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        if (pose.sanskritName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            pose.sanskritName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              Chip(
                avatar: const Icon(Icons.signal_cellular_alt, size: 18),
                label: Text(yogaDifficultyLabel(l10n, pose.difficulty)),
              ),
              if (pose.category.isNotEmpty)
                Chip(label: Text(pose.category)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed:
                () =>
                    ref.read(yogaRepositoryProvider).toggleFavorite(pose.key),
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
            ),
            label: Text(
              isFavorite ? l10n.yogaRemoveFavorite : l10n.yogaAddFavorite,
            ),
          ),
        ),
        if (pose.description.isNotEmpty)
          _section(theme, l10n.yogaOverview, Text(pose.description)),
        if (pose.benefits.isNotEmpty)
          _section(theme, l10n.yogaBenefits, Text(pose.benefits)),
        if (pose.instructions.isNotEmpty)
          _section(
            theme,
            l10n.yogaInstructions,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < pose.instructions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text('${i + 1}.'),
                        ),
                        Expanded(child: Text(pose.instructions[i])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (pose.breathing.isNotEmpty)
          _section(theme, l10n.yogaBreathing, Text(pose.breathing)),
        if (pose.contraindications.isNotEmpty)
          _section(
            theme,
            l10n.yogaTakeCare,
            Text(
              pose.contraindications,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          l10n.yogaSafetyNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _section(ThemeData theme, String title, Widget child) {
    final style = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.45,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          DefaultTextStyle.merge(style: style, child: child),
        ],
      ),
    );
  }
}
