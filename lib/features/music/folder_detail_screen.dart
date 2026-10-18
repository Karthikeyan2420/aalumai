import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/theme/module_theme.dart';
import 'data/music_providers.dart';
import 'data/music_repository.dart';
import 'data/player_service.dart';
import 'track_actions.dart';
import 'widgets/music_widgets.dart';

/// Shows the songs contained in a single device folder.
class FolderDetailScreen extends ConsumerWidget {
  const FolderDetailScreen({super.key, required this.folder});

  final MusicFolderSummary folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(musicTracksProvider);
    final accent = ModuleAccents.music;

    return Scaffold(
      appBar: AppBar(title: Text(folder.name.isEmpty ? '—' : folder.name)),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final tracks = all.where((t) => t.folderPath == folder.path).toList();
          if (tracks.isEmpty) {
            return Center(child: Text(context.l10n.emptyMusic));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${tracks.length} · ${context.l10n.tracks}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: accent),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(context.l10n.playAll),
                      onPressed:
                          () => ref
                              .read(musicPlayerProvider.notifier)
                              .playQueue(tracks, 0),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final current =
                        ref.watch(musicPlayerProvider).current?.id == track.id;
                    return TrackTile(
                      track: track,
                      isCurrent: current,
                      onTap:
                          () => ref
                              .read(musicPlayerProvider.notifier)
                              .playQueue(tracks, index),
                      onFavorite:
                          () => ref
                              .read(musicRepositoryProvider)
                              .toggleFavorite(track),
                      onMenu: () => showTrackActions(context, ref, track),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
