import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Distance Material 3 keeps between a floating snackbar and the edges of the
/// screen.
const double _edgeInset = 16;

/// Material 3 caps a snackbar's width so it stays readable on large screens.
const double _maxWidth = 560;

/// The space Material 3 leaves around the text of a floating snackbar.
///
/// The message owns it (the snackbar itself gets [EdgeInsets.zero]) so the
/// message's height is the whole surface, which lets the exit animation
/// collapse that surface.
const EdgeInsets _contentPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 14,
);

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
      content: _AppSnackBarMessage(message),
      behavior: SnackBarBehavior.floating,
      // The message carries the padding; see _AppSnackBarMessage.
      padding: EdgeInsets.zero,
      margin: EdgeInsets.fromLTRB(inset, 0, inset, _edgeInset),
    ),
  );
}

/// The text of an app snackbar, and the snackbar's exit animation.
///
/// Material 3's floating snackbar animates its height on the way in but not on
/// the way out: the reverse holds the height and only fades the surface for the
/// middle fifth of the transition, so the snackbar reads as disappearing at
/// once. The [SnackBar] exposes the animation that drives both, so the message
/// collapses its own height over the same reverse (and with the same curve the
/// height grows in): the surface shrinks towards the bottom edge until the
/// messenger removes it when the transition ends.
class _AppSnackBarMessage extends StatefulWidget {
  const _AppSnackBarMessage(this.message);

  final String message;

  @override
  State<_AppSnackBarMessage> createState() => _AppSnackBarMessageState();
}

class _AppSnackBarMessageState extends State<_AppSnackBarMessage> {
  /// The animation of the enclosing [SnackBar], null outside one.
  Animation<double>? _animation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animation = context.findAncestorWidgetOfExactType<SnackBar>()?.animation;
  }

  @override
  Widget build(BuildContext context) {
    final message = Padding(
      padding: _contentPadding,
      child: Text(widget.message),
    );
    final animation = _animation;
    if (animation == null) return message;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Align(
        alignment: Alignment.bottomLeft,
        heightFactor: animation.status == AnimationStatus.reverse
            ? Curves.easeInOutQuart.transform(animation.value)
            : 1,
        child: child,
      ),
      child: message,
    );
  }
}
