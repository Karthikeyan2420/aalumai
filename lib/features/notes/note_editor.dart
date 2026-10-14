import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import '../settings/data/lock_service.dart';
import 'data/note_repository.dart';

Future<void> showNoteEditor(BuildContext context, {required int noteId}) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: noteId)));
}

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});
  final int noteId;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final note = await ref.read(noteRepositoryProvider).getById(widget.noteId);
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

  Future<void> _save() async {
    final note = _note;
    if (note == null) return;
    await ref
        .read(noteRepositoryProvider)
        .updateNote(
          note.copyWith(
            title: _title.text.trim(),
            body: _body.text,
            kind: _isJournal ? NoteKind.journal.index : NoteKind.note.index,
            updatedAt: DateTime.now(),
          ),
        );
    if (mounted) Navigator.pop(context);
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

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: l10n.journalEntry,
            icon: Icon(_isJournal ? Icons.book : Icons.book_outlined),
            onPressed: () => setState(() => _isJournal = !_isJournal),
          ),
          IconButton(
            tooltip: l10n.noteLock,
            icon: Icon(locked ? Icons.lock : Icons.lock_open),
            onPressed: _toggleLock,
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
              ),
            ),
          ],
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
