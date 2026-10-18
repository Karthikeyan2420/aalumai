import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n_extension.dart';
import '../../../core/theme/module_theme.dart';
import '../data/music_repository.dart';
import '../data/player_service.dart';
import '../now_playing_screen.dart';
import 'music_widgets.dart';

/// A compact, always-available player shown above the music navigation while a
/// track is loaded. Tapping it opens the full Now Playing screen.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final track = state.current;
    if (track == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final accent = ModuleAccents.music;
    final progress =
        state.duration.inMilliseconds == 0
            ? 0.0
            : (state.position.inMilliseconds / state.duration.inMilliseconds)
                .clamp(0.0, 1.0);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NowPlayingScreen()),
            ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  AlbumArt(track: track, size: 44, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title.isEmpty ? track.uri : track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          track.artist.isEmpty ? track.album : track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    tooltip: context.l10n.play,
                    icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
                    onPressed: controller.togglePlay,
                  ),
                  IconButton(
                    tooltip: context.l10n.playNext,
                    icon: const Icon(Icons.skip_next),
                    onPressed: controller.next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
