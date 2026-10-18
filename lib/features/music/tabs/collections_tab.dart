import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/localization/l10n_extension.dart';
import '../../../core/theme/module_theme.dart';
import '../add_to_collection.dart';
import '../collection_detail_screen.dart';
import '../data/music_providers.dart';
import '../widgets/music_widgets.dart';

/// Custom playlists and labels, grouped into two sections.
class CollectionsTab extends ConsumerWidget {
  const CollectionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final labels = ref.watch(labelsProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        _CollectionSection(
          title: context.l10n.playlists,
          icon: Icons.queue_music,
          kind: 'playlist',
          collections: playlists,
        ),
        const SizedBox(height: 8),
        _CollectionSection(
          title: context.l10n.labels,
          icon: Icons.label_outline,
          kind: 'label',
          collections: labels,
        ),
      ],
    );
  }
}

class _CollectionSection extends ConsumerWidget {
  const _CollectionSection({
    required this.title,
    required this.icon,
    required this.kind,
    required this.collections,
  });

  final String title;
  final IconData icon;
  final String kind;
  final AsyncValue<List<Playlist>> collections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: ModuleAccents.music),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    () => showCreateCollectionDialog(context, ref, kind: kind),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  kind == 'label'
                      ? context.l10n.createLabel
                      : context.l10n.newPlaylist,
                ),
              ),
            ],
          ),
        ),
        collections.when(
          loading:
              () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (e, _) =>
                  Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  context.l10n.noMusicYet,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [for (final c in items) _CollectionTile(playlist: c)],
            );
          },
        ),
      ],
    );
  }
}

class _CollectionTile extends ConsumerWidget {
  const _CollectionTile({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = collectionColor(playlist);
    final tracksAsync = ref.watch(collectionTracksProvider(playlist.id));
    final count = tracksAsync.valueOrNull?.length;
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          playlist.kind == 'label' ? Icons.label : Icons.queue_music,
          color: Colors.white,
        ),
      ),
      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle:
          playlist.description.isNotEmpty
              ? Text(
                playlist.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
              : (count != null
                  ? Text('$count · ${context.l10n.tracks}')
                  : null),
      trailing: const Icon(Icons.chevron_right),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CollectionDetailScreen(playlist: playlist),
            ),
          ),
    );
  }
}
