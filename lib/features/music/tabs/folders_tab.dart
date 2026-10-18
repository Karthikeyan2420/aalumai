import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n_extension.dart';
import '../../../core/theme/module_theme.dart';
import '../data/music_providers.dart';
import '../folder_detail_screen.dart';
import '../widgets/music_widgets.dart';

/// The device folders that contain indexed songs.
class FoldersTab extends ConsumerWidget {
  const FoldersTab({super.key, this.onScan});

  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(musicFolderSummariesProvider);
    final accent = ModuleAccents.music;
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (folders) {
        if (folders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.noFolders,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (onScan != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onScan,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.scanDevice),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 12),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            final folder = folders[index];
            return ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: softTint(context, accent, 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.folder, color: accent),
              ),
              title: Text(
                folder.name.isEmpty ? folder.path : folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${folder.trackCount} · ${formatDurationMs(folder.durationMs)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FolderDetailScreen(folder: folder),
                    ),
                  ),
            );
          },
        );
      },
    );
  }
}
