import 'package:flutter/material.dart';

import '../database/note.dart';
import '../database/note_dao.dart';
import '../utils/app_snack_bar.dart';
import '../widgets/app_content.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/note_form.dart';
import '../widgets/status_views.dart';

/// Screen used to read, change and delete a single note.
///
/// The note is loaded from the database when the screen opens, so the screen
/// also works when the note was deleted in the meantime.
class EditNoteScreen extends StatefulWidget {
  const EditNoteScreen({
    super.key,
    required this.noteDao,
    required this.noteId,
  });

  final NoteDao noteDao;

  /// Id of the note that has to be shown.
  final int noteId;

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  Note? _note;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    try {
      final note = await widget.noteDao.getNoteById(widget.noteId);
      if (!mounted) {
        return;
      }
      setState(() {
        _note = note;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('EditNoteScreen: could not load the note - $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'The note could not be loaded.';
        _isLoading = false;
      });
    }
  }

  Future<bool> _updateNote(Note note) async {
    final updatedRows = await widget.noteDao.updateNote(note);
    if (!mounted) {
      return false;
    }
    if (updatedRows == 0) {
      // The note was deleted in the meantime. There is nothing left to save,
      // the form closes itself and the list reloads the notes.
      showAppSnackBar(context, 'This note has been deleted.');
      return true;
    }
    setState(() => _note = note);
    return true;
  }

  Future<void> _deleteNote() async {
    final note = _note;
    if (note == null || _isDeleting) {
      return;
    }
    final confirmed = await confirmDeleteNote(context, preview: note.content);
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await widget.noteDao.deleteNote(note);
    } catch (error) {
      debugPrint('EditNoteScreen: could not delete the note - $error');
      if (!mounted) {
        return;
      }
      setState(() => _isDeleting = false);
      showAppSnackBar(context, 'The note could not be deleted.');
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete note',
            color: Theme.of(context).colorScheme.error,
            onPressed: _note == null || _isDeleting ? null : _deleteNote,
          ),
        ],
      ),
      body: AppContent(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return MessageView(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: errorMessage,
        actionLabel: 'Try again',
        onAction: _loadNote,
      );
    }
    if (_isLoading) {
      return const LoadingView();
    }
    final note = _note;
    if (note == null) {
      return MessageView(
        icon: Icons.search_off,
        title: 'Note not found',
        message: 'This note does not exist anymore.',
        actionLabel: 'Back to the notes',
        onAction: () => Navigator.of(context).pop(false),
      );
    }
    return NoteForm(note: note, onSave: _updateNote);
  }
}
