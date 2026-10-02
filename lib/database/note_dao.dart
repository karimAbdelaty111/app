import 'package:floor/floor.dart';

import 'note.dart';

/// All database operations used by the application.
///
/// Every method is asynchronous, the generated implementation takes care of
/// running them on a background database executor.
@dao
abstract class NoteDao {
  /// Inserts [note] and returns the id of the created row.
  @Insert()
  Future<int> insertNote(Note note);

  /// Updates the row matching [Note.id] and returns the number of changed
  /// rows, so `0` means that the note no longer exists.
  @Update()
  Future<int> updateNote(Note note);

  /// Deletes the row matching [Note.id] and returns the number of deleted
  /// rows, so `0` means that the note no longer exists.
  @delete
  Future<int> deleteNote(Note note);

  /// Returns a single note, or `null` when the id is unknown.
  @Query('SELECT * FROM notes WHERE id = :id')
  Future<Note?> getNoteById(int id);

  /// Returns all notes, newest first.
  @Query('SELECT * FROM notes ORDER BY createdAt DESC, id DESC')
  Future<List<Note>> getAllNotes();

  /// Removes every note.
  @Query('DELETE FROM notes')
  Future<void> deleteAllNotes();
}
