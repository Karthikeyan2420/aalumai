import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/database.dart';
import '../../../core/localization/l10n_extension.dart';
import 'data/music_repository.dart';
import 'widgets/music_widgets.dart';

/// Accent colours offered for custom collections.
const kCollectionPalette = <int>[
  0xFF8B5CF6, // purple
  0xFF3B82F6, // blue
  0xFF14B8A6, // teal
  0xFF22C55E, // green
  0xFFF97316, // orange
  0xFFEC4899, // pink
  0xFFEF4444, // red
  0xFFEAB308, // amber
];

/// Creates a playlist or label and returns its id, or null when cancelled.
Future<int?> showCreateCollectionDialog(
  BuildContext context,
  WidgetRef ref, {
  String kind = 'playlist',
}) async {
  final l10n = context.l10n;
  final nameCtrl = TextEditingController();
  var color = kCollectionPalette.first;
  final result = await showDialog<_CollectionDraft>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: Text(
                  kind == 'label' ? l10n.createLabel : l10n.newPlaylist,
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(labelText: l10n.name),
                    ),
                    const SizedBox(height: 16),
                    _ColorPicker(
                      selected: color,
                      onChanged: (c) => setState(() => color = c),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed:
                        () => Navigator.pop(
                          context,
                          _CollectionDraft(nameCtrl.text.trim(), color),
                        ),
                    child: Text(l10n.save),
                  ),
                ],
              ),
        ),
  );
  if (result == null || result.name.isEmpty) return null;
  return ref
      .read(musicRepositoryProvider)
      .createCollection(
        name: result.name,
        kind: kind,
        accentColor: result.color,
      );
}

/// Edits an existing collection's name, colour, description and cover.
Future<void> showEditCollectionDialog(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist,
) async {
  final l10n = context.l10n;
  final nameCtrl = TextEditingController(text: playlist.name);
  final descCtrl = TextEditingController(text: playlist.description);
  var color = playlist.accentColor ?? kCollectionPalette.first;
  var cover = playlist.coverUri;

  final result = await showDialog<_CollectionDraft>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: Text(l10n.edit),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(labelText: l10n.name),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: l10n.description,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ColorPicker(
                        selected: color,
                        onChanged: (c) => setState(() => color = c),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final path = await _pickCover();
                          if (path != null) setState(() => cover = path);
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: Text(l10n.coverImage),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed:
                        () => Navigator.pop(
                          context,
                          _CollectionDraft(
                            nameCtrl.text.trim(),
                            color,
                            descCtrl.text.trim(),
                            cover,
                          ),
                        ),
                    child: Text(l10n.save),
                  ),
                ],
              ),
        ),
  );
  if (result == null || result.name.isEmpty) return;
  await ref
      .read(musicRepositoryProvider)
      .updateCollection(
        playlist.id,
        name: result.name,
        accentColor: result.color,
        coverUri: result.cover,
        description: result.description,
      );
}

/// Shows a picker to add one or more tracks to an existing or brand-new
/// collection (playlists and labels are both offered).
Future<void> showAddToCollectionSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<int> trackIds,
}) async {
  if (trackIds.isEmpty) return;
  final l10n = context.l10n;
  final collections =
      await ref.read(musicRepositoryProvider).watchCollections().first;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l10n.addToPlaylist,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final c in collections)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: collectionColor(c),
                    radius: 14,
                  ),
                  title: Text(c.name),
                  subtitle: Text(
                    c.kind == 'label' ? l10n.label : l10n.playlist,
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await ref
                        .read(musicRepositoryProvider)
                        .addManyToCollection(c.id, trackIds);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.newPlaylist),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final id = await showCreateCollectionDialog(
                    context,
                    ref,
                    kind: 'playlist',
                  );
                  if (id != null) {
                    await ref
                        .read(musicRepositoryProvider)
                        .addManyToCollection(id, trackIds);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(l10n.createLabel),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final id = await showCreateCollectionDialog(
                    context,
                    ref,
                    kind: 'label',
                  );
                  if (id != null) {
                    await ref
                        .read(musicRepositoryProvider)
                        .addManyToCollection(id, trackIds);
                  }
                },
              ),
            ],
          ),
        ),
  );
}

Future<String?> _pickCover() async {
  try {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final source = result?.files.single.path;
    if (source == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final coverDir = Directory(p.join(dir.path, 'music_covers'));
    if (!await coverDir.exists()) await coverDir.create(recursive: true);
    final target = p.join(
      coverDir.path,
      'cover_${DateTime.now().millisecondsSinceEpoch}${p.extension(source)}',
    );
    await File(source).copy(target);
    return target;
  } catch (_) {
    return null;
  }
}

class _CollectionDraft {
  const _CollectionDraft(
    this.name,
    this.color, [
    this.description = '',
    this.cover = '',
  ]);
  final String name;
  final int color;
  final String description;
  final String cover;
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final value in kCollectionPalette)
          GestureDetector(
            onTap: () => onChanged(value),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Color(value),
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected == value
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child:
                  selected == value
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
            ),
          ),
      ],
    );
  }
}
