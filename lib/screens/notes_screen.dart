import 'package:flutter/material.dart';

import '../database/database.dart';
import '../database/note.dart';
import '../database/note_dao.dart';
import '../services/shake_service.dart';
import '../utils/app_snack_bar.dart';
import '../widgets/app_content.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/note_card.dart';
import '../widgets/status_views.dart';
import 'add_note_screen.dart';
import 'edit_note_screen.dart';

/// Main screen of the app, it lists all notes of the database.
///
/// Shaking the device asks the user whether every note should be deleted.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final ShakeService _shakeService;

  NoteDao? _noteDao;
  String? _databaseError;
  List<Note> _notes = const <Note>[];
  bool _isLoadingNotes = true;
  String? _notesError;

  /// Set while the delete all dialog is open, so a single shake cannot open
  /// the dialog more than once.
  bool _isDeleteAllPending = false;

  @override
  void initState() {
    super.initState();
    _shakeService = ShakeService(onShake: _handleShake);
    _shakeService.start();
    _openDatabase();
  }

  @override
  void dispose() {
    _shakeService.dispose();
    super.dispose();
  }

  Future<void> _openDatabase() async {
    setState(() => _databaseError = null);
    try {
      final database = await AppDatabase.open();
      if (!mounted) {
        return;
      }
      setState(() => _noteDao = database.noteDao);
      await _loadNotes();
    } catch (error) {
      debugPrint('NotesScreen: could not open the database - $error');
      if (!mounted) {
        return;
      }
      setState(
        () => _databaseError =
            'The notes database could not be opened. '
            'Please try again.',
      );
    }
  }

  /// Reads all notes from the database and shows them.
  ///
  /// [showLoader] is turned off for the pull to refresh gesture, so the list
  /// stays visible instead of being replaced by the spinner.
  Future<void> _loadNotes({bool showLoader = true}) async {
    final noteDao = _noteDao;
    if (noteDao == null) {
      return;
    }
    setState(() {
      if (showLoader) {
        _isLoadingNotes = true;
      }
      _notesError = null;
    });
    try {
      final notes = await noteDao.getAllNotes();
      if (!mounted) {
        return;
      }
      setState(() {
        _notes = notes;
        _isLoadingNotes = false;
      });
    } catch (error) {
      debugPrint('NotesScreen: could not load the notes - $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingNotes = false;
        _notesError = 'The notes could not be loaded.';
      });
    }
  }

  Future<void> _addNote() async {
    final noteDao = _noteDao;
    if (noteDao == null) {
      return;
    }
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddNoteScreen(noteDao: noteDao)),
    );
    if (added == true) {
      await _loadNotes();
    }
  }

  Future<void> _openNote(Note note) async {
    final noteDao = _noteDao;
    final noteId = note.id;
    if (noteDao == null || noteId == null) {
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditNoteScreen(noteDao: noteDao, noteId: noteId),
      ),
    );
    if (changed == true) {
      await _loadNotes();
    }
  }

  /// Asks for confirmation and deletes every note when the device is shaken.
  Future<void> _handleShake() async {
    if (_isDeleteAllPending || !mounted) {
      return;
    }
    if (_notes.isEmpty) {
      showAppSnackBar(context, 'There are no notes to delete.');
      return;
    }

    _isDeleteAllPending = true;
    try {
      final confirmed = await confirmDeleteAllNotes(
        context,
        noteCount: _notes.length,
      );
      if (!confirmed || !mounted) {
        return;
      }
      await _deleteAllNotes();
    } finally {
      _isDeleteAllPending = false;
    }
  }

  Future<void> _deleteAllNotes() async {
    final noteDao = _noteDao;
    if (noteDao == null) {
      return;
    }
    final noteCount = _notes.length;
    try {
      await noteDao.deleteAllNotes();
      if (!mounted) {
        return;
      }
      await _loadNotes();
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        noteCount == 1 ? '1 note deleted.' : '$noteCount notes deleted.',
      );
    } catch (error) {
      debugPrint('NotesScreen: could not delete all notes - $error');
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, 'The notes could not be deleted.');
    }
  }

  Future<void> _deleteNoteFromList(Note note) async {
    final noteDao = _noteDao;
    if (noteDao == null) {
      return;
    }
    try {
      await noteDao.deleteNote(note);
      if (!mounted) {
        return;
      }
      await _loadNotes();
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        'Note deleted',
        actionLabel: 'UNDO',
        onAction: () => _restoreNote(note),
      );
    } catch (error) {
      debugPrint('NotesScreen: could not delete the note - $error');
      if (mounted) {
        showAppSnackBar(context, 'The note could not be deleted.');
      }
    }
  }

  Future<void> _restoreNote(Note note) async {
    final noteDao = _noteDao;
    if (noteDao == null) {
      return;
    }
    try {
      await noteDao.insertNote(
        Note(
          content: note.content,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          latitude: note.latitude,
          longitude: note.longitude,
          accuracy: note.accuracy,
          locationName: note.locationName,
        ),
      );
      if (mounted) {
        await _loadNotes();
      }
    } catch (error) {
      debugPrint('NotesScreen: could not restore the note - $error');
      if (mounted) {
        showAppSnackBar(context, 'The note could not be restored.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Notes'),
            Text(
              _notes.isEmpty
                  ? 'Your thoughts, organized.'
                  : '${_notes.length} ${_notes.length == 1 ? 'note' : 'notes'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (_notes.isNotEmpty && _noteDao != null)
            IconButton(
              onPressed: _handleShake,
              tooltip: 'Delete all notes',
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      floatingActionButton: _noteDao == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addNote,
              tooltip: 'Add note',
              icon: const Icon(Icons.add),
              label: const Text('New note'),
            ),
      body: AppContent(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final databaseError = _databaseError;
    if (databaseError != null) {
      return MessageView(
        icon: Icons.error_outline,
        title: 'Database unavailable',
        message: databaseError,
        actionLabel: 'Try again',
        onAction: _openDatabase,
      );
    }
    final notesError = _notesError;
    if (notesError != null) {
      return MessageView(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: notesError,
        actionLabel: 'Try again',
        onAction: _loadNotes,
      );
    }
    if (_isLoadingNotes) {
      return const LoadingView();
    }
    if (_notes.isEmpty) {
      return MessageView(
        icon: Icons.note_add_outlined,
        title: 'No notes yet',
        message: 'Start writing down your thoughts.',
        actionLabel: 'Create note',
        onAction: _noteDao == null ? null : _addNote,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadNotes(showLoader: false),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 104),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          return NoteCard(
            note: note,
            onTap: () => _openNote(note),
            onDelete: () => _deleteNoteFromList(note),
          );
        },
      ),
    );
  }
}
