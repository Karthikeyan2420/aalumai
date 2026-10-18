import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import 'add_to_collection.dart';
import 'data/music_providers.dart';
import 'data/music_repository.dart';
import 'data/player_service.dart';
import 'track_actions.dart';
import 'widgets/music_widgets.dart';

/// Detail view for a playlist or label: header, play/shuffle, reorderable track
/// list with multi-select removal and per-track actions.
class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen({super.key, required this.playlist});

  final Playlist playlist;

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  final _selected = <int>{};

  bool get _selectionMode => _selected.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final tracksAsync = ref.watch(collectionTracksProvider(playlist.id));
    final accent = collectionColor(playlist);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions:
            _selectionMode
                ? [
                  IconButton(
                    tooltip: context.l10n.selectAll,
                    icon: const Icon(Icons.select_all),
                    onPressed: () {
                      final tracks = tracksAsync.valueOrNull ?? [];
                      setState(() {
                        if (_selected.length == tracks.length) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(tracks.map((t) => t.id));
                        }
                      });
                    },
                  ),
                  IconButton(
                    tooltip: context.l10n.delete,
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removeSelected(playlist.id),
                  ),
                  IconButton(
                    tooltip: context.l10n.close,
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(_selected.clear),
                  ),
                ]
                : [
                  IconButton(
                    tooltip: context.l10n.add,
                    icon: const Icon(Icons.add),
                    onPressed: () => _addTracks(playlist.id),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        showEditCollectionDialog(context, ref, playlist);
                      } else if (value == 'delete') {
                        _confirmDelete(playlist);
                      }
                    },
                    itemBuilder:
                        (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(context.l10n.edit),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(context.l10n.delete),
                          ),
                        ],
                  ),
                ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(musicRepositoryProvider).scanDevice(),
        child: tracksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (tracks) {
            if (tracks.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
                  Center(
                    child: Text(
                      context.l10n.emptyPlaylist,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _Header(playlist: playlist, accent: accent, tracks: tracks),
                Expanded(
                  child: ReorderableListView.builder(
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final ids = tracks.map((t) => t.id).toList();
                      final moved = ids.removeAt(oldIndex);
                      ids.insert(newIndex, moved);
                      ref
                          .read(musicRepositoryProvider)
                          .reorderCollectionItems(playlist.id, ids);
                    },
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final current =
                          ref.watch(musicPlayerProvider).current?.id ==
                          track.id;
                      return TrackTile(
                        key: ValueKey('${track.id}-$index'),
                        track: track,
                        isCurrent: current,
                        selectionMode: _selectionMode,
                        selected: _selected.contains(track.id),
                        onTap:
                            _selectionMode
                                ? () => _toggle(track.id)
                                : () => ref
                                    .read(musicPlayerProvider.notifier)
                                    .playQueue(tracks, index),
                        onLongPress: () => setState(() => _toggle(track.id)),
                        onFavorite:
                            () => ref
                                .read(musicRepositoryProvider)
                                .toggleFavorite(track),
                        onMenu:
                            () => showTrackActions(
                              context,
                              ref,
                              track,
                              fromCollectionId: playlist.id,
                            ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _toggle(int id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  Future<void> _removeSelected(int collectionId) async {
    await ref
        .read(musicRepositoryProvider)
        .removeManyFromCollection(collectionId, _selected.toList());
    if (mounted) setState(_selected.clear);
  }

  Future<void> _addTracks(int collectionId) async {
    final all = await ref.read(musicTracksProvider.future);
    if (!mounted) return;
    final memberIds = await ref
        .read(musicRepositoryProvider)
        .collectionMemberIds(collectionId);
    if (!mounted) return;
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (_) => _TrackPicker(
            tracks: all.where((t) => !memberIds.contains(t.id)).toList(),
          ),
    );
    if (picked != null && picked.isNotEmpty) {
      await ref
          .read(musicRepositoryProvider)
          .addManyToCollection(collectionId, picked);
    }
  }

  Future<void> _confirmDelete(Playlist playlist) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(context.l10n.deleteConfirmTitle),
            content: Text(context.l10n.deleteConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.delete),
              ),
            ],
          ),
    );
    if (ok == true) {
      await ref.read(musicRepositoryProvider).deleteCollection(playlist.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.playlist,
    required this.accent,
    required this.tracks,
  });

  final Playlist playlist;
  final Color accent;
  final List<MusicTrack> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(musicPlayerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Hero(
            tag: 'collection-${playlist.id}',
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(18),
              ),
              child:
                  playlist.coverUri.isNotEmpty
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(
                          File(playlist.coverUri),
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Icon(
                                playlist.kind == 'label'
                                    ? Icons.label
                                    : Icons.queue_music,
                                color: Colors.white,
                                size: 40,
                              ),
                        ),
                      )
                      : Icon(
                        playlist.kind == 'label'
                            ? Icons.label
                            : Icons.queue_music,
                        color: Colors.white,
                        size: 40,
                      ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (playlist.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      playlist.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Text(
                  '${tracks.length} · ${context.l10n.tracks}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: accent),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(context.l10n.playAll),
                      onPressed:
                          tracks.isEmpty
                              ? null
                              : () => controller.playQueue(tracks, 0),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: Text(context.l10n.shuffleAll),
                      onPressed:
                          tracks.isEmpty
                              ? null
                              : () {
                                controller.setShuffle(true);
                                controller.playQueue(tracks, 0);
                              },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A scrollable, searchable picker used to add tracks to a collection.
class _TrackPicker extends StatefulWidget {
  const _TrackPicker({required this.tracks});

  final List<MusicTrack> tracks;

  @override
  State<_TrackPicker> createState() => _TrackPickerState();
}

class _TrackPickerState extends State<_TrackPicker> {
  final _selected = <int>{};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final term = _search.trim().toLowerCase();
    final filtered =
        term.isEmpty
            ? widget.tracks
            : widget.tracks
                .where(
                  (t) =>
                      t.title.toLowerCase().contains(term) ||
                      t.artist.toLowerCase().contains(term),
                )
                .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: context.l10n.search,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final track = filtered[index];
                return CheckboxListTile(
                  value: _selected.contains(track.id),
                  onChanged:
                      (_) => setState(() {
                        if (!_selected.add(track.id)) {
                          _selected.remove(track.id);
                        }
                      }),
                  secondary: AlbumArt(track: track, size: 40),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  dense: true,
                  activeColor: theme.colorScheme.primary,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selected.toList()),
                child: Text('${context.l10n.add} (${_selected.length})'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
