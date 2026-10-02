import 'package:flutter_test/flutter_test.dart';
import 'package:noteapp/database/database.dart';
import 'package:noteapp/database/note.dart';
import 'package:noteapp/database/note_dao.dart';

void main() {
  late NoteDao noteDao;

  setUp(() async {
    final database = await AppDatabase.openInMemory();
    noteDao = database.noteDao;
  });

  tearDown(() => AppDatabase.closeInstance());

  Note buildNote(String content, {DateTime? createdAt}) {
    final timestamp = createdAt ?? DateTime(2024, 5, 1, 12);
    return Note(
      content: content,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  group('NoteDao', () {
    test('starts without notes', () async {
      expect(await noteDao.getAllNotes(), isEmpty);
    });

    test('inserts a note and reads it back by id', () async {
      final id = await noteDao.insertNote(buildNote('Buy milk'));

      expect(id, greaterThan(0));

      final stored = await noteDao.getNoteById(id);
      expect(stored?.content, 'Buy milk');
      expect(stored?.hasLocation, isFalse);
      expect(stored?.createdAt, DateTime(2024, 5, 1, 12));
    });

    test('returns null for an unknown id', () async {
      expect(await noteDao.getNoteById(404), isNull);
    });

    test('keeps the location of a note', () async {
      final id = await noteDao.insertNote(
        buildNote('At the library').copyWith(
          latitude: 51.50735,
          longitude: -0.12776,
          accuracy: 8.4,
        ),
      );

      final stored = await noteDao.getNoteById(id);
      expect(stored?.hasLocation, isTrue);
      expect(stored?.latitude, 51.50735);
      expect(stored?.longitude, -0.12776);
      expect(stored?.accuracy, 8.4);
    });

    test('updates the content and the location of a note', () async {
      final id = await noteDao.insertNote(buildNote('Draft'));
      final stored = await noteDao.getNoteById(id);

      final updatedRows = await noteDao.updateNote(
        stored!.copyWith(
          content: 'Final version',
          latitude: 48.1372,
          longitude: 11.5755,
          updatedAt: DateTime(2024, 5, 2, 8),
        ),
      );

      expect(updatedRows, 1);
      final reloaded = await noteDao.getNoteById(id);
      expect(reloaded?.content, 'Final version');
      expect(reloaded?.latitude, 48.1372);
      expect(reloaded?.createdAt, DateTime(2024, 5, 1, 12));
      expect(reloaded?.isEdited, isTrue);
    });

    test('removes the location when it is cleared', () async {
      final id = await noteDao.insertNote(
        buildNote('With position')
            .copyWith(latitude: 1, longitude: 2, accuracy: 3),
      );
      final stored = await noteDao.getNoteById(id);

      await noteDao.updateNote(stored!.copyWith(clearLocation: true));

      final reloaded = await noteDao.getNoteById(id);
      expect(reloaded?.hasLocation, isFalse);
      expect(reloaded?.latitude, isNull);
    });

    test('reports zero changed rows when the note no longer exists', () async {
      final deletedNote = buildNote('Missing').copyWith(id: 999);

      expect(await noteDao.updateNote(deletedNote), 0);
      expect(await noteDao.deleteNote(deletedNote), 0);
    });

    test('deletes a single note', () async {
      final id = await noteDao.insertNote(buildNote('Delete me'));
      final stored = await noteDao.getNoteById(id);

      expect(await noteDao.deleteNote(stored!), 1);
      expect(await noteDao.getNoteById(id), isNull);
      expect(await noteDao.getAllNotes(), isEmpty);
    });

    test('returns the newest note first', () async {
      await noteDao.insertNote(buildNote('Older', createdAt: DateTime(2024, 1, 1)));
      await noteDao.insertNote(buildNote('Newer', createdAt: DateTime(2024, 6, 1)));

      final notes = await noteDao.getAllNotes();
      expect(notes.map((note) => note.content), ['Newer', 'Older']);
    });

    test('deletes every note', () async {
      await noteDao.insertNote(buildNote('One'));
      await noteDao.insertNote(buildNote('Two'));

      await noteDao.deleteAllNotes();

      expect(await noteDao.getAllNotes(), isEmpty);
    });
  });
}
