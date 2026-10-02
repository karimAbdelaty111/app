import 'package:flutter/material.dart';

/// Confirmation dialogs of the destructive actions.
///
/// They always return a real boolean, a cancelled dialog is treated the same
/// way as a declined one.
Future<bool> confirmDeleteNote(
  BuildContext context, {
  required String preview,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete note?'),
      content: Text('This cannot be undone.\n\n"${_shorten(preview)}"'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Keeps long notes readable inside the confirmation dialog.
String _shorten(String value, {int maxLength = 80}) {
  final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (singleLine.length <= maxLength) {
    return singleLine;
  }
  return '${singleLine.substring(0, maxLength)}...';
}

/// Asks the user to confirm the deletion of every note, used by the shake
/// gesture on the notes list.
Future<bool> confirmDeleteAllNotes(
  BuildContext context, {
  required int noteCount,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: const Text('Delete all notes?'),
        content: Text(
          'This will permanently delete $noteCount '
          '${noteCount == 1 ? 'note' : 'notes'}. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
