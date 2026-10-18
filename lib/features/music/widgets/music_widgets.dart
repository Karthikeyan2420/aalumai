import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../core/db/database.dart';
import '../../../core/localization/l10n_extension.dart';
import '../../../core/theme/module_theme.dart';

/// Formats a track duration as `M:SS` or `H:MM:SS`. Pure helper for tests.
String formatDurationMs(int milliseconds) {
  if (milliseconds <= 0) return '0:00';
  final totalSeconds = milliseconds ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final mm = minutes.toString().padLeft(2, '0');
    return '$hours:$mm:$ss';
  }
  return '$minutes:$ss';
}

String formatDuration(Duration d) => formatDurationMs(d.inMilliseconds);

/// Human-readable storage size. Pure helper for tests.
String formatStorageSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text =
      value >= 100 || unit == 0
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// Rounded album artwork with a consistent pastel placeholder when MediaStore
/// has no embedded image. Uses the real embedded artwork when available.
class AlbumArt extends StatelessWidget {
  const AlbumArt({
    super.key,
    required this.track,
    this.size = 48,
    this.radius = 12,
  });

  final MusicTrack track;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final mediaId = int.tryParse(track.mediaId);
    final placeholder = _placeholder(context);
    final art =
        (mediaId != null && mediaId > 0)
            ? QueryArtworkWidget(
              id: mediaId,
              type: ArtworkType.AUDIO,
              size: (size * 3).round(),
              quality: 50,
              artworkBorder: BorderRadius.circular(radius),
              nullArtworkWidget: placeholder,
              errorBuilder: (_, __, ___) => placeholder,
            )
            : placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: art),
    );
  }

  Widget _placeholder(BuildContext context) {
    final accent = ModuleAccents.music;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            softTint(context, accent, 0.35),
            softTint(context, accent, 0.14),
          ],
        ),
      ),
      child: Icon(Icons.music_note, color: accent, size: size * 0.45),
    );
  }
}

/// A section heading inside the songs list (e.g. "Today", "This week").
class GroupHeader extends StatelessWidget {
  const GroupHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A single song row used across the Songs, Favorites, Folder and Collection
/// lists. Supports compact/regular layouts and multi-select.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.isCurrent = false,
    this.isPlaying = false,
    this.selectionMode = false,
    this.selected = false,
    this.compact = false,
    this.onLongPress,
    this.onFavorite,
    this.onMenu,
  });

  final MusicTrack track;
  final VoidCallback onTap;
  final bool isCurrent;
  final bool isPlaying;
  final bool selectionMode;
  final bool selected;
  final bool compact;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavorite;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ModuleAccents.music;
    final titleColor = isCurrent ? accent : theme.colorScheme.onSurface;
    final subtitle =
        track.isMissing
            ? context.l10n.missingFiles
            : (track.artist.isNotEmpty ? track.artist : track.album);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? softTint(context, accent, 0.14) : null,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 6 : 8,
        ),
        child: Row(
          children: [
            if (selectionMode) ...[
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? accent : theme.colorScheme.outline,
              ),
              const SizedBox(width: 12),
            ] else if (!compact) ...[
              AlbumArt(track: track, size: 48),
              const SizedBox(width: 12),
            ] else ...[
              AlbumArt(track: track, size: 36, radius: 8),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (isCurrent) ...[
                        Icon(
                          isPlaying ? Icons.equalizer : Icons.pause_circle,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          track.title.isEmpty ? track.uri : track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            track.isMissing
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (!selectionMode) ...[
              const SizedBox(width: 8),
              Text(
                formatDurationMs(track.durationMs),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (onFavorite != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.l10n.favorite,
                  icon: Icon(
                    track.isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color:
                        track.isFavorite ? accent : theme.colorScheme.outline,
                  ),
                  onPressed: onFavorite,
                ),
              if (onMenu != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.l10n.more,
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: onMenu,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The colour to use for a custom collection, falling back to the music accent.
Color collectionColor(Playlist playlist) =>
    playlist.accentColor != null
        ? Color(playlist.accentColor!)
        : ModuleAccents.music;

/// Loading / error / empty / permission states for the music module.
class MusicPermissionView extends StatelessWidget {
  const MusicPermissionView({
    super.key,
    required this.permanentlyDenied,
    required this.onGrant,
    required this.onOpenSettings,
  });

  final bool permanentlyDenied;
  final VoidCallback onGrant;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 56,
              color: ModuleAccents.music,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.permissionDeniedTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.permissionDeniedBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (permanentlyDenied)
              FilledButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
                label: Text(l10n.openSettings),
              )
            else
              FilledButton.icon(
                onPressed: onGrant,
                icon: const Icon(Icons.check),
                label: Text(l10n.grantPermission),
              ),
          ],
        ),
      ),
    );
  }
}
