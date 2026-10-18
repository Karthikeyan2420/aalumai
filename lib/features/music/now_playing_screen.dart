import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/theme/module_theme.dart';
import 'add_to_collection.dart';
import 'data/music_repository.dart';
import 'data/player_service.dart';
import 'widgets/music_widgets.dart';

/// Full-screen playback view with artwork, transport controls, seek bar,
/// shuffle/repeat, favourite and the reorderable play queue.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  double? _dragValue;

  /// Track the drag belongs to. A scrub that outlives its track (the queue
  /// advanced while the user's finger was down) must not be applied to the new
  /// track, so the value is only honoured when both still match.
  int? _dragTrackId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final track = state.current;
    final theme = Theme.of(context);
    final accent = ModuleAccents.music;

    if (track == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.l10n.noMusicYet)),
      );
    }

    final totalMs =
        state.duration.inMilliseconds > 0
            ? state.duration.inMilliseconds
            : track.durationMs;
    final positionMs = state.position.inMilliseconds.clamp(0, totalMs);
    final dragging = _dragTrackId == track.id;
    final sliderValue = (dragging ? _dragValue : null) ?? positionMs.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.nowPlaying),
        actions: [
          IconButton(
            tooltip: context.l10n.queue,
            icon: const Icon(Icons.queue_music),
            onPressed: () => _showQueue(context, ref),
          ),
          IconButton(
            tooltip: context.l10n.more,
            icon: const Icon(Icons.more_vert),
            onPressed:
                () => showAddToCollectionSheet(
                  context,
                  ref,
                  trackIds: [track.id],
                ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AspectRatio(
                aspectRatio: 1,
                child: Hero(
                  tag: 'now-playing-art',
                  child: AlbumArt(
                    track: track,
                    size: MediaQuery.sizeOf(context).width - 64,
                    radius: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    track.title.isEmpty ? track.uri : track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      track.artist,
                      track.album,
                    ].where((s) => s.isNotEmpty).join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  thumbColor: accent,
                  trackHeight: 3,
                ),
                child: Slider(
                  value:
                      totalMs == 0
                          ? 0
                          : sliderValue.clamp(0, totalMs.toDouble()),
                  max: totalMs == 0 ? 1 : totalMs.toDouble(),
                  onChangeStart:
                      totalMs == 0
                          ? null
                          : (_) => setState(() => _dragTrackId = track.id),
                  onChanged:
                      totalMs == 0
                          ? null
                          : (v) => setState(() {
                            _dragValue = v;
                            _dragTrackId = track.id;
                          }),
                  onChangeEnd: (v) {
                    controller.seek(Duration(milliseconds: v.round()));
                    setState(() {
                      _dragValue = null;
                      _dragTrackId = null;
                    });
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDurationMs(sliderValue.round()),
                    style: theme.textTheme.labelMedium,
                  ),
                  Text(
                    formatDurationMs(totalMs),
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: context.l10n.shuffleAll,
                  icon: Icon(
                    Icons.shuffle,
                    color: state.shuffle ? accent : theme.colorScheme.outline,
                  ),
                  onPressed: () => controller.setShuffle(!state.shuffle),
                ),
                const SizedBox(width: 8),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.skip_previous),
                  onPressed: controller.previous,
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 40,
                    color: Colors.white,
                    icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
                    onPressed: controller.togglePlay,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.skip_next),
                  onPressed: controller.next,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _repeatTooltip(context, state.repeat),
                  icon: Icon(
                    state.repeat == RepeatMode.one
                        ? Icons.repeat_one
                        : Icons.repeat,
                    color:
                        state.repeat == RepeatMode.off
                            ? theme.colorScheme.outline
                            : accent,
                  ),
                  onPressed: controller.cycleRepeat,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: context.l10n.favorite,
                  icon: Icon(
                    track.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: track.isFavorite ? accent : null,
                  ),
                  onPressed:
                      () => ref
                          .read(musicRepositoryProvider)
                          .toggleFavorite(track),
                ),
                IconButton(
                  tooltip: context.l10n.addToPlaylist,
                  icon: const Icon(Icons.playlist_add),
                  onPressed:
                      () => showAddToCollectionSheet(
                        context,
                        ref,
                        trackIds: [track.id],
                      ),
                ),
                IconButton(
                  tooltip: context.l10n.sleepTimer,
                  icon: const Icon(Icons.bedtime_outlined),
                  onPressed: () => _showSleepTimer(context, ref),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  String _repeatTooltip(BuildContext context, RepeatMode mode) =>
      switch (mode) {
        RepeatMode.off => context.l10n.repeatOff,
        RepeatMode.all => context.l10n.repeatAll,
        RepeatMode.one => context.l10n.repeatOne,
      };

  void _showQueue(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _QueueSheet(),
    );
  }

  void _showSleepTimer(BuildContext context, WidgetRef ref) {
    final controller = ref.read(musicPlayerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final minutes in [10, 20, 30, 45, 60])
                  ListTile(
                    leading: const Icon(Icons.bedtime_outlined),
                    title: Text('$minutes min'),
                    onTap: () {
                      controller.startSleepTimer(Duration(minutes: minutes));
                      Navigator.pop(sheetContext);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: Text(context.l10n.cancel),
                  onTap: () {
                    controller.cancelSleepTimer();
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
    );
  }
}

/// A reorderable list of the current queue with skip and remove actions.
class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final accent = ModuleAccents.music;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.queue,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: controller.clearQueue,
                  child: Text(context.l10n.clear),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: state.queue.length,
              onReorder: controller.reorderQueue,
              itemBuilder: (context, index) {
                final track = state.queue[index];
                final isCurrent = index == state.index;
                return ListTile(
                  key: ValueKey('${track.id}-$index'),
                  leading:
                      isCurrent
                          ? Icon(Icons.equalizer, color: accent)
                          : Text('${index + 1}'),
                  title: Text(
                    track.title.isEmpty ? track.uri : track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? accent : null,
                      fontWeight: isCurrent ? FontWeight.w700 : null,
                    ),
                  ),
                  subtitle: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.removeFromQueue,
                    onPressed: () => controller.removeFromQueue(index),
                  ),
                  onTap: () => controller.jumpTo(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
