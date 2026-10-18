import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/module_theme.dart';
import '../../core/widgets/dashboard_components.dart';
import 'data/music_providers.dart';
import 'data/music_repository.dart';
import 'data/player_service.dart';
import 'widgets/music_widgets.dart';

/// Library statistics: counts, totals, recently added, most played, probable
/// duplicates and the play history.
class MusicStatsScreen extends ConsumerWidget {
  const MusicStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(libraryStatsProvider);
    final historyAsync = ref.watch(musicHistoryProvider);
    final duplicatesAsync = ref.watch(duplicatesProvider);
    final accent = ModuleAccents.music;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.statistics)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(libraryStatsProvider);
          ref.invalidate(duplicatesProvider);
          await ref.read(musicRepositoryProvider).scanDevice();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            statsAsync.when(
              loading:
                  () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error: (e, _) => Text('$e'),
              data: (stats) => _StatsBody(stats: stats, accent: accent),
            ),
            const SizedBox(height: 8),
            _Section(
              title: context.l10n.history,
              action: TextButton(
                onPressed:
                    () => ref.read(musicRepositoryProvider).clearHistory(),
                child: Text(context.l10n.clearHistory),
              ),
              child: historyAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text('$e'),
                data: (tracks) {
                  if (tracks.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        context.l10n.noMusicYet,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final t in tracks.take(20))
                        _MiniTrackRow(track: t, accent: accent),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _Section(
              title: context.l10n.duplicates,
              child: duplicatesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text('$e'),
                data: (groups) {
                  if (groups.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        context.l10n.noMusicYet,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final g in groups) _DuplicateGroupTile(group: g),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats, required this.accent});

  final LibraryStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: [
            StatTile(
              icon: Icons.music_note,
              label: context.l10n.songs,
              value: '${stats.songCount}',
              accent: accent,
            ),
            StatTile(
              icon: Icons.album,
              label: context.l10n.album,
              value: '${stats.albumCount}',
              accent: accent,
            ),
            StatTile(
              icon: Icons.person_outline,
              label: context.l10n.artist,
              value: '${stats.artistCount}',
              accent: accent,
            ),
            StatTile(
              icon: Icons.folder_outlined,
              label: context.l10n.folders,
              value: '${stats.folderCount}',
              accent: accent,
            ),
            StatTile(
              icon: Icons.favorite_border,
              label: context.l10n.favorites,
              value: '${stats.favoriteCount}',
              accent: accent,
            ),
            StatTile(
              icon: Icons.error_outline,
              label: context.l10n.missingFiles,
              value: '${stats.missingCount}',
              accent: accent,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: [
              _TotalRow(
                icon: Icons.timer_outlined,
                label: context.l10n.duration,
                value: _formatTotalDuration(stats.totalDurationMs),
              ),
              const Divider(height: 20),
              _TotalRow(
                icon: Icons.sd_storage_outlined,
                label: context.l10n.size,
                value: formatStorageSize(stats.totalSizeBytes),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (stats.mostPlayed.isNotEmpty) ...[
          SectionHeader(title: context.l10n.mostPlayed),
          for (final t in stats.mostPlayed)
            _MiniTrackRow(
              track: t,
              accent: accent,
              trailing: '${t.playCount}×',
            ),
        ],
        if (stats.recentlyAdded.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionHeader(title: context.l10n.recentlyAdded),
          for (final t in stats.recentlyAdded)
            _MiniTrackRow(track: t, accent: accent),
        ],
      ],
    );
  }

  String _formatTotalDuration(int ms) {
    final total = Duration(milliseconds: ms);
    final hours = total.inHours;
    final minutes = total.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: ModuleAccents.music),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SectionHeader(title: title, action: action), child],
      ),
    );
  }
}

class _MiniTrackRow extends ConsumerWidget {
  const _MiniTrackRow({
    required this.track,
    required this.accent,
    this.trailing,
  });

  final MusicTrack track;
  final Color accent;
  final String? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => ref.read(musicPlayerProvider.notifier).playTrack(track),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AlbumArt(track: track, size: 40, radius: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title.isEmpty ? track.uri : track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: theme.textTheme.labelMedium?.copyWith(color: accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _DuplicateGroupTile extends StatelessWidget {
  const _DuplicateGroupTile({required this.group});

  final DuplicateGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        group.tracks.first.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${group.tracks.length} · ${group.tracks.first.artist}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      children: [
        for (final t in group.tracks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.uri,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  formatStorageSize(t.sizeBytes),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
