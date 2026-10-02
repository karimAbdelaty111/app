import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteapp/database/database.dart';
import 'package:noteapp/database/note.dart';
import 'package:noteapp/database/note_dao.dart';
import 'package:noteapp/screens/notes_screen.dart';

void main() {
  late NoteDao noteDao;
  late _FakeAccelerometer accelerometer;

  setUp(() async {
    accelerometer = _FakeAccelerometer()..register();
    final database = await AppDatabase.openInMemory();
    noteDao = database.noteDao;
  });

  tearDown(() async {
    accelerometer.unregister();
    await AppDatabase.closeInstance();
  });

  Future<void> pumpUntilReady(WidgetTester tester) async {
    for (var attempt = 0; attempt < 30; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        await tester.pump(const Duration(milliseconds: 350));
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> openNotesScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotesScreen()));
    await pumpUntilReady(tester);
  }

  Future<void> addNote(WidgetTester tester, String text) async {
    await tester.tap(find.byTooltip('Add note'));
    await pumpUntilReady(tester);

    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.widgetWithText(FilledButton, 'Add note'));
    await pumpUntilReady(tester);
  }

  Future<void> shakeDevice(WidgetTester tester) async {
    await tester.runAsync(accelerometer.shake);
    await pumpUntilReady(tester);
  }

  Future<void> insertNote(String content) async {
    final now = DateTime(2024, 5, 1, 12);
    await noteDao.insertNote(
      Note(content: content, createdAt: now, updatedAt: now),
    );
  }

  testWidgets('shows the empty state when there are no notes', (tester) async {
    await openNotesScreen(tester);

    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('adds a note and shows it in the list', (tester) async {
    await openNotesScreen(tester);

    await addNote(tester, 'Buy milk');

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('No notes yet'), findsNothing);
    expect(await noteDao.getAllNotes(), hasLength(1));
  });

  testWidgets('does not save an empty note', (tester) async {
    await openNotesScreen(tester);

    await tester.tap(find.byTooltip('Add note'));
    await pumpUntilReady(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add note'));
    await pumpUntilReady(tester);

    expect(find.text('The note cannot be empty'), findsOneWidget);
    expect(await noteDao.getAllNotes(), isEmpty);
  });

  testWidgets('deletes a note from the list and restores it with undo', (
    tester,
  ) async {
    await insertNote('Recoverable note');
    await openNotesScreen(tester);

    await tester.tap(find.byTooltip('Delete note'));
    await pumpUntilReady(tester);

    expect(find.text('Recoverable note'), findsNothing);
    expect(find.text('UNDO'), findsOneWidget);
    expect(await noteDao.getAllNotes(), isEmpty);

    await tester.tap(find.text('UNDO'));
    await pumpUntilReady(tester);

    expect(find.text('Recoverable note'), findsOneWidget);
    expect(await noteDao.getAllNotes(), hasLength(1));
  });

  testWidgets('edits a note and keeps the change', (tester) async {
    await insertNote('Draft');
    await openNotesScreen(tester);

    await tester.tap(find.text('Draft'));
    await pumpUntilReady(tester);
    await tester.enterText(find.byType(TextField), 'Final version');
    await tester.tap(find.widgetWithText(FilledButton, 'Update note'));
    await pumpUntilReady(tester);

    expect(find.text('Final version'), findsOneWidget);
    expect(find.text('Draft'), findsNothing);
    expect((await noteDao.getAllNotes()).single.content, 'Final version');
  });

  testWidgets('deletes a single note after confirmation', (tester) async {
    await insertNote('Delete me');
    await openNotesScreen(tester);

    await tester.tap(find.text('Delete me'));
    await pumpUntilReady(tester);
    await tester.tap(find.byTooltip('Delete note'));
    await pumpUntilReady(tester);
    expect(find.text('Delete note?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await pumpUntilReady(tester);

    expect(find.text('Delete me'), findsNothing);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(await noteDao.getAllNotes(), isEmpty);
  });

  testWidgets('keeps the note when the delete dialog is cancelled', (
    tester,
  ) async {
    await insertNote('Keep me');
    await openNotesScreen(tester);

    await tester.tap(find.text('Keep me'));
    await pumpUntilReady(tester);
    await tester.tap(find.byTooltip('Delete note'));
    await pumpUntilReady(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await pumpUntilReady(tester);

    expect(find.text('Keep me'), findsOneWidget);
    expect(await noteDao.getAllNotes(), hasLength(1));
  });

  group('shake to delete all notes', () {
    testWidgets('deletes every note after the confirmation', (tester) async {
      await insertNote('One');
      await insertNote('Two');
      await openNotesScreen(tester);

      await shakeDevice(tester);
      expect(find.text('Delete all notes?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete all'));
      await pumpUntilReady(tester);

      expect(find.text('No notes yet'), findsOneWidget);
      expect(await noteDao.getAllNotes(), isEmpty);
    });

    testWidgets('keeps the notes when the shake is cancelled', (tester) async {
      await insertNote('One');
      await openNotesScreen(tester);

      await shakeDevice(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await pumpUntilReady(tester);

      expect(find.text('One'), findsOneWidget);
      expect(await noteDao.getAllNotes(), hasLength(1));
    });

    testWidgets('only asks once for a single shake', (tester) async {
      await insertNote('One');
      await openNotesScreen(tester);

      await shakeDevice(tester);
      await shakeDevice(tester);

      expect(find.text('Delete all notes?'), findsOneWidget);
      expect(await noteDao.getAllNotes(), hasLength(1));
    });

    testWidgets('reports that there is nothing to delete', (tester) async {
      await openNotesScreen(tester);

      await shakeDevice(tester);

      expect(find.text('There are no notes to delete.'), findsOneWidget);
      expect(find.text('Delete all notes?'), findsNothing);
    });
  });
}

/// Replaces the accelerometer of the `shake` package, so a shake gesture can
/// be simulated in a widget test.
class _FakeAccelerometer {
  MockStreamHandlerEventSink? _events;

  void register() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      (call) async => null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/sensors/accelerometer'),
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          _events = events;
        },
      ),
    );
  }

  void unregister() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/sensors/accelerometer'),
      null,
    );
  }

  /// Sends two movements that are far enough apart to be recognized as a
  /// shake. The `shake` package measures the time between the movements with
  /// [DateTime.now], so the delays have to be real ones.
  Future<void> shake() async {
    final events = _events;
    if (events == null) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    events.success(_strongMovement());
    await Future<void>.delayed(const Duration(milliseconds: 700));
    events.success(_strongMovement());
  }

  /// Movement of roughly 3 g, which is above the shake threshold.
  List<double> _strongMovement() => <double>[
    0,
    0,
    30,
    DateTime.now().microsecondsSinceEpoch.toDouble(),
  ];
}
