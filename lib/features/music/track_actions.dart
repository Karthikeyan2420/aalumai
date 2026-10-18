import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import 'add_to_collection.dart';
import 'data/music_repository.dart';
import 'data/player_service.dart';

/// Bottom sheet of actions for a single track, reused by every list.
Future<void> showTrackActions(
  BuildContext context,
  WidgetRef ref,
  MusicTrack track, {
  int? fromCollectionId,
  VoidCallback? onRemoved,
}) async {
  final l10n = context.l10n;
  final controller = ref.read(musicPlayerProvider.notifier);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (sheetContext) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: Text(l10n.play),
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.playTrack(track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_play),
                title: Text(l10n.playNext),
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.playNext(track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(l10n.addToQueue),
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.addToQueue(track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(l10n.addToPlaylist),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showAddToCollectionSheet(context, ref, trackIds: [track.id]);
                },
              ),
              ListTile(
                leading: Icon(
                  track.isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                title: Text(l10n.favorite),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref.read(musicRepositoryProvider).toggleFavorite(track);
                },
              ),
              if (fromCollectionId != null)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline),
                  title: Text(l10n.removeFromPlaylist),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ref
                        .read(musicRepositoryProvider)
                        .removeFromCollection(fromCollectionId, track.id);
                    onRemoved?.call();
                  },
                ),
            ],
          ),
        ),
  );
}
