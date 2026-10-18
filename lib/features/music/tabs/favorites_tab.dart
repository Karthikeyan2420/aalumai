import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n_extension.dart';
import '../data/music_providers.dart';
import '../data/music_repository.dart';
import '../data/player_service.dart';
import '../track_actions.dart';
import '../widgets/music_widgets.dart';

/// Every song the user has marked as a favourite.
class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(musicFavoritesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (tracks) {
        if (tracks.isEmpty) {
          return _Empty(icon: Icons.favorite_border);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 12),
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
                  () => ref.read(musicRepositoryProvider).toggleFavorite(track),
              onMenu: () => showTrackActions(context, ref, track),
            );
          },
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              context.l10n.noMusicYet,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
