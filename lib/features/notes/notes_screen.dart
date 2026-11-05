import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/module_theme.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_scaffold.dart';
import 'data/note_repository.dart';
import 'note_editor.dart';
import '../expenses/item_actions.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final repo = ref.watch(noteRepositoryProvider);
    final stream = _query.isEmpty ? repo.watchAll() : repo.search(_query);

    return Scaffold(
      appBar: AppBar(
        title:
            _searching
                ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.search,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                )
                : Text(l10n.notes),
        backgroundColor: softTint(context, DashboardModule.notes.accent, 0.08),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed:
                () => setState(() {
                  _searching = !_searching;
                  if (!_searching) {
                    _searchController.clear();
                    _query = '';
                  }
                }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'notesAdd',
        onPressed: () {
          showNoteEditor(context);
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.add),
      ),
      body: StreamBuilder<List<Note>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) return const LoadingState();
          final notes = snapshot.data!;
          if (notes.isEmpty) {
            return EmptyState(
              icon: Icons.edit_note_outlined,
              message: l10n.emptyNotes,
              accent: DashboardModule.notes.accent,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              12,
              AppSpacing.screen,
              96,
            ),
            itemCount: notes.length,
            separatorBuilder:
                (_, __) => const SizedBox(height: AppSpacing.cardGap),
            itemBuilder: (context, index) {
              final note = notes[index];
              return _NoteTile(
                note: note,
                onTap: () => showNoteEditor(context, noteId: note.id),
                onPin: () => repo.togglePinned(note),
                onFavorite: () => repo.toggleFavorite(note),
                onDelete: () async {
                  if (note.isLocked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.locked)),
                    );
                    return;
                  }
                  final ok = await confirmDialog(
                    context,
                    title: l10n.deleteConfirmTitle,
                    body: l10n.deleteConfirmBody,
                    confirmLabel: l10n.delete,
                  );
                  if (ok) await repo.delete(note.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onTap,
    required this.onPin,
    required this.onFavorite,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onFavorite;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final title = note.title.trim().isEmpty ? l10n.emptyTitle : note.title;
    final body = note.isLocked ? '••••••' : note.body.trim();
    return ModuleListTile(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (note.kind == NoteKind.journal.index)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.book_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              if (note.isLocked)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (note.isPinned)
                Icon(
                  Icons.push_pin,
                  size: 18,
                  color: theme.colorScheme.tertiary,
                ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                DateFormat.yMMMd().add_jm().format(note.updatedAt),
                style: theme.textTheme.labelSmall,
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(
                  note.isFavorite ? Icons.star : Icons.star_border,
                  size: 22,
                ),
                onPressed: onFavorite,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(
                  note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 22,
                ),
                onPressed: onPin,
              ),
              itemMoreButton(
                onPressed:
                    () => showEditDeleteMenu(
                      context,
                      onEdit: onTap,
                      onDelete: onDelete,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
