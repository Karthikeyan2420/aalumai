import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import '../settings/data/lock_service.dart';
import 'data/note_repository.dart';

/// Opens the note editor. Pass [noteId] to edit an existing note, or omit it to
/// open a new, unsaved draft.
///
/// A draft is never written to the database until the user explicitly saves
/// meaningful content, so cancelling or leaving an empty "New Note" creates
/// nothing.
Future<void> showNoteEditor(BuildContext context, {int? noteId}) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: noteId)));
}

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.noteId});

  /// `null` means a new draft that has not been persisted yet.
  final int? noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  Note? _note;
  bool _loading = true;
  bool _unlocked = false;
  bool _isJournal = false;
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.noteId;
    if (id == null) {
      // Draft: nothing is loaded and nothing is persisted until the user saves.
      if (!mounted) return;
      setState(() {
        _note = null;
        _unlocked = true;
        _loading = false;
      });
      return;
    }
    final note = await ref.read(noteRepositoryProvider).getById(id);
    if (!mounted) return;
    setState(() {
      _note = note;
      _title.text = note?.title ?? '';
      _body.text = note?.body ?? '';
      _isJournal = note?.kind == NoteKind.journal.index;
      _unlocked = !(note?.isLocked ?? false);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async => _persist(popAfter: true);

  Future<void> _persist({required bool popAfter}) async {
    final kind = _isJournal ? NoteKind.journal.index : NoteKind.note.index;
    final title = _title.text.trim();
    final body = _body.text;
    final note = _note;

    if (note == null) {
      // Draft: only persist when the user entered meaningful content.
      if (title.isEmpty && body.trim().isEmpty) {
        if (mounted) Navigator.pop(context);
        return;
      }
      await ref
          .read(noteRepositoryProvider)
          .create(title: title, body: body, kind: NoteKind.fromIndex(kind));
      if (mounted && popAfter) Navigator.pop(context);
      return;
    }

    await ref
        .read(noteRepositoryProvider)
        .updateNote(
          note.copyWith(
            title: title,
            body: body,
            kind: kind,
            updatedAt: DateTime.now(),
          ),
        );
    _dirty = false;
    if (mounted && popAfter) Navigator.pop(context);
  }

  Future<void> _unlock() async {
    final lock = ref.read(lockServiceProvider);
    if (!await lock.hasPin) {
      final ok = await _setPin();
      if (!ok) return;
    }
    if (!mounted) return;
    final pin = await _promptPin(context);
    if (pin == null) return;
    if (await lock.verify(pin)) {
      setState(() => _unlocked = true);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.incorrect)));
    }
  }

  Future<bool> _setPin() async {
    if (!mounted) return false;
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(context.l10n.noteLock),
            content: TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'PIN'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(context.l10n.save),
              ),
            ],
          ),
    );
    if (pin != null && pin.length >= 4) {
      await ref.read(lockServiceProvider).setPin(pin);
      return true;
    }
    return false;
  }

  Future<void> _delete() async {
    final note = _note;
    if (note == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (note.isLocked && !_unlocked) {
      await _unlock();
      if (!mounted || !_unlocked) return;
    }
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.deleteConfirmTitle,
      body: l10n.deleteConfirmBody,
      confirmLabel: l10n.delete,
    );
    if (ok) {
      await ref.read(noteRepositoryProvider).delete(note.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_dirty) return true;
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.discardChanges),
            content: Text(l10n.deleteConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.keepEditing),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.yes),
              ),
            ],
          ),
    );
    if (discard == true) return true;
    if (discard == false) {
      await _persist(popAfter: false);
      return true;
    }
    return false;
  }

  Future<void> _toggleLock() async {
    final note = _note;
    if (note == null) return;
    final repo = ref.read(noteRepositoryProvider);
    if (note.isLocked) {
      await repo.toggleLocked(note, false);
      setState(() {
        _note = note.copyWith(isLocked: false);
        _unlocked = true;
      });
    } else {
      final lock = ref.read(lockServiceProvider);
      if (!await lock.hasPin && !await _setPin()) return;
      await repo.toggleLocked(note, true);
      setState(() {
        _note = note.copyWith(isLocked: true);
        _unlocked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return const Scaffold(body: LoadingState());
    }

    final locked = _note?.isLocked ?? false;
    if (locked && !_unlocked) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.lock_outline,
          message: l10n.locked,
          actionLabel: l10n.open,
          onAction: _unlock,
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _onWillPop() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            if (_note != null)
              IconButton(
                tooltip: l10n.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
          IconButton(
            tooltip: l10n.journalEntry,
            icon: Icon(_isJournal ? Icons.book : Icons.book_outlined),
            onPressed: () => setState(() => _isJournal = !_isJournal),
          ),
          if (_isJournal)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  l10n.journalEntry,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          IconButton(
            tooltip: l10n.noteLock,
            icon: Icon(locked ? Icons.lock : Icons.lock_open),
            onPressed: _note == null ? null : _toggleLock,
          ),
          IconButton(
            tooltip: l10n.save,
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _title,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: InputDecoration(
                hintText: l10n.title,
                border: InputBorder.none,
                filled: false,
              ),
              onChanged: (_) => _markDirty(),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _body,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: l10n.notes,
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (_) => _markDirty(),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

Future<String?> _promptPin(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(context.l10n.locked),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'PIN'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(context.l10n.open),
            ),
          ],
        ),
  );
  return result;
}
