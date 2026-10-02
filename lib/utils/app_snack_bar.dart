import 'package:flutter/material.dart';

/// Shows [message] in a snack bar.
///
/// The previous snack bar is replaced so a quick series of messages, for
/// example the result of a delete action, cannot queue up.
void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: actionLabel == null
            ? const Duration(seconds: 4)
            : const Duration(seconds: 6),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}
