import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/music_repository.dart';
import 'data/player_service.dart';

class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.music),
          actions: [
            IconButton(
              tooltip: l10n.addMusicFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: () => _addFolder(context, ref),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.tracks),
              Tab(text: l10n.favorites),
              Tab(text: l10n.recentlyPlayed),
              Tab(text: l10n.playlists),
            ],
          ),
        ),
        body: const Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _TrackList(mode: _TrackMode.all),
                  _TrackList(mode: _TrackMode.favorites),
                  _TrackList(mode: _TrackMode.recent),
                  _PlaylistsTab(),
                ],
              ),
            ),
            _PlayerBar(),
          ],
        ),
      ),
    );
  }

  static Future<void> _addFolder(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) return;
      final added = await ref.read(musicRepositoryProvider).addFolder(path);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$added ${l10n.tracks}')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.permissionDeniedBody)));
      }
    }
  }
}

enum _TrackMode { all, favorites, recent }

class _TrackList extends ConsumerWidget {
  const _TrackList({required this.mode});
  final _TrackMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = switch (mode) {
      _TrackMode.all => ref.watch(musicTracksProvider),
      _TrackMode.favorites => ref.watch(musicFavoritesProvider),
      _TrackMode.recent => ref.watch(musicRecentProvider),
    };
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (tracks) {
        if (tracks.isEmpty) {
          return EmptyState(
            icon: Icons.library_music_outlined,
            message: l10n.emptyMusic,
            actionLabel: l10n.addMusicFolder,
            onAction: () => MusicScreen._addFolder(context, ref),
          );
        }
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, i) {
            final track = tracks[i];
            final current = ref.watch(musicPlayerProvider).current;
            final isCurrent = current?.id == track.id;
            return ListTile(
              leading: Icon(
                isCurrent ? Icons.music_note : Icons.audiotrack,
                color:
                    isCurrent ? Theme.of(context).colorScheme.secondary : null,
              ),
              title: Text(track.title.isEmpty ? track.uri : track.title),
              subtitle: Text(track.artist),
              trailing: IconButton(
                icon: Icon(
                  track.isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                onPressed:
                    () =>
                        ref.read(musicRepositoryProvider).toggleFavorite(track),
              ),
              onTap:
                  () => ref
                      .read(musicPlayerProvider.notifier)
                      .playQueue(tracks, i),
            );
          },
        );
      },
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playlists = ref.watch(playlistsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _createPlaylist(context, ref),
        child: const Icon(Icons.add),
      ),
      body: playlists.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data:
            (list) =>
                list.isEmpty
                    ? EmptyState(
                      icon: Icons.queue_music_outlined,
                      message: l10n.playlists,
                      actionLabel: l10n.add,
                      onAction: () => _createPlaylist(context, ref),
                    )
                    : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final p = list[i];
                        return ListTile(
                          leading: const Icon(Icons.queue_music),
                          title: Text(p.name),
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => PlaylistDetailScreen(playlist: p),
                                ),
                              ),
                        );
                      },
                    ),
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.playlists),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.save),
              ),
            ],
          ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(musicRepositoryProvider).createPlaylist(ctrl.text.trim());
    }
  }
}

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlist});
  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(_playlistTracksProvider(playlist.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: context.l10n.deleteConfirmTitle,
                body: context.l10n.deleteConfirmBody,
                confirmLabel: context.l10n.delete,
              );
              if (ok && context.mounted) {
                await ref
                    .read(musicRepositoryProvider)
                    .deletePlaylist(playlist.id);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: tracks.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data:
            (list) =>
                list.isEmpty
                    ? const EmptyState(
                      icon: Icons.queue_music_outlined,
                      message: 'Empty playlist',
                    )
                    : ListView.builder(
                      itemCount: list.length,
                      itemBuilder:
                          (context, i) => ListTile(
                            leading: const Icon(Icons.audiotrack),
                            title: Text(list[i].title),
                            onTap:
                                () => ref
                                    .read(musicPlayerProvider.notifier)
                                    .playQueue(list, i),
                          ),
                    ),
      ),
    );
  }
}

final _playlistTracksProvider = StreamProvider.family<List<MusicTrack>, int>((
  ref,
  playlistId,
) {
  return ref.watch(musicRepositoryProvider).watchPlaylistTracks(playlistId);
});

class _PlayerBar extends ConsumerWidget {
  const _PlayerBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final track = state.current;
    if (track == null) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.error != null)
              Text(
                l10n.permissionDeniedBody,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Slider(
              value:
                  state.duration.inMilliseconds == 0
                      ? 0
                      : state.position.inMilliseconds
                          .clamp(0, state.duration.inMilliseconds)
                          .toDouble(),
              max: state.duration.inMilliseconds.clamp(1, 1 << 31).toDouble(),
              onChanged:
                  (v) => controller.seek(Duration(milliseconds: v.round())),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    state.shuffle ? Icons.shuffle_on_outlined : Icons.shuffle,
                  ),
                  onPressed: () => controller.setShuffle(!state.shuffle),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: controller.previous,
                ),
                IconButton(
                  icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
                  onPressed: controller.togglePlay,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: controller.next,
                ),
                IconButton(
                  icon: Icon(
                    state.repeat == RepeatMode.off
                        ? Icons.repeat
                        : state.repeat == RepeatMode.one
                        ? Icons.repeat_one
                        : Icons.repeat_on_outlined,
                  ),
                  onPressed: () {
                    final next = switch (state.repeat) {
                      RepeatMode.off => RepeatMode.all,
                      RepeatMode.all => RepeatMode.one,
                      RepeatMode.one => RepeatMode.off,
                    };
                    controller.setRepeat(next);
                  },
                ),
                IconButton(
                  tooltip: l10n.sleepTimer,
                  icon: const Icon(Icons.bedtime_outlined),
                  onPressed:
                      () => controller.startSleepTimer(
                        const Duration(minutes: 30),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
