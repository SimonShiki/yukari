import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Distance Material 3 keeps between a floating snackbar and the edges of the
/// screen.
const double _edgeInset = 16;

/// Material 3 caps a snackbar's width so it stays readable on large screens.
const double _maxWidth = 560;

/// Shows [message] in a Material 3 snackbar.
///
/// Call this instead of `ScaffoldMessenger.showSnackBar` directly so every
/// message is placed the same way. Floating is what lets the enclosing
/// [Scaffold] nudge the snackbar above a floating action button or bottom
/// navigation bar rather than covering them. The margin confines it to
/// [_maxWidth], keeps it clear of the screen edges, and leaves the space
/// between it and its neighbours tappable, so it never spans the full width and
/// never sits in front of the navigation area.
void showAppSnackBar(BuildContext context, String message) {
  final double inset = math.max(
    _edgeInset,
    (MediaQuery.sizeOf(context).width - _maxWidth) / 2,
  );
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(inset, 0, inset, _edgeInset),
    ),
  );
}
