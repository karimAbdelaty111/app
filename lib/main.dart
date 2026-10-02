import 'package:flutter/material.dart';

import 'database/database.dart';
import 'database/database_factory.dart';
import 'screens/notes_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prepares the right sqflite implementation for the platform, this only
  // changes something in the browser.
  await setupDatabaseFactory();

  // Opening the database here means it is ready before the first screen asks
  // for it. `open` keeps a single instance for the whole app. If it fails the
  // notes screen shows the error and offers a retry, so the app still starts.
  try {
    await AppDatabase.open();
  } catch (error) {
    debugPrint('main: the database could not be opened - $error');
  }

  runApp(const NotesApp());
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes',
      theme: AppTheme.light,
      home: const NotesScreen(),
    );
  }
}