import 'package:flutter/material.dart';

import '../database/note.dart';
import '../database/note_dao.dart';
import '../widgets/app_content.dart';
import '../widgets/note_form.dart';

/// Screen used to write a new note.
class AddNoteScreen extends StatelessWidget {
  const AddNoteScreen({super.key, required this.noteDao});

  final NoteDao noteDao;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New note')),
      body: AppContent(child: NoteForm(onSave: _insertNote)),
    );
  }

  Future<bool> _insertNote(Note note) async {
    await noteDao.insertNote(note);
    return true;
  }
}
