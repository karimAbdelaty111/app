import 'package:flutter/material.dart';

/// Centers the content of a screen and keeps it readable on wide screens or
/// tablets, where a full width list would be hard to read.
class AppContent extends StatelessWidget {
  const AppContent({super.key, required this.child});

  /// Maximum width of the content on large screens.
  static const double maxContentWidth = 600;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
