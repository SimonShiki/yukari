import 'package:flutter/services.dart' show PredictiveBackEvent;
import 'package:material_ui/material_ui.dart';

/// What a predictive back gesture is doing to a route.
enum PredictiveBackPhase {
  /// No gesture is running: the route's animation alone drives the transition.
  idle,

  /// A finger is dragging in from an edge, and the route follows it.
  update,

  /// The finger lifted past the commit point: the route is finishing its pop.
  commit,

  /// The finger lifted before the commit point: the route is springing back.
  cancel,
}

/// A back gesture's live state.
@immutable
class PredictiveBackGesture {
  const PredictiveBackGesture({required this.phase, required this.released});

  /// No gesture has run.
  static const PredictiveBackGesture idle = PredictiveBackGesture(
    phase: PredictiveBackPhase.idle,
    released: 1,
  );

  final PredictiveBackPhase phase;

  /// How open the route was when the finger lifted, from zero (fully shrunk)
  /// to one (covering the window). A settled gesture animates from here, so it
  /// continues the drag instead of restarting it.
  final double released;

  @override
  bool operator ==(Object other) =>
      other is PredictiveBackGesture &&
      other.phase == phase &&
      other.released == released;

  @override
  int get hashCode => Object.hash(phase, released);

  @override
  String toString() => 'PredictiveBackGesture($phase, released: $released)';
}

/// Follows this route's predictive back gesture and hands the framework's
/// callbacks to [TransitionRoute.handleStartBackGesture] and its siblings, which
/// scrub the route's own animation.
///
/// Flutter's equivalent, `_PredictiveBackGestureDetector`, lives inside the
/// material library's private transition, so a route with a transition of its
/// own cannot reuse it. This forwards the same public callbacks to the same
/// public route API, keeping the gesture in charge of the route's animation, and
/// reports the release point so the transition can carry the motion on.
class PredictiveBackGestureDetector extends StatefulWidget {
  const PredictiveBackGestureDetector({
    super.key,
    required this.route,
    required this.builder,
  });

  final PageRoute<dynamic> route;

  final Widget Function(BuildContext context, PredictiveBackGesture gesture)
  builder;

  @override
  State<PredictiveBackGestureDetector> createState() =>
      _PredictiveBackGestureDetectorState();
}

class _PredictiveBackGestureDetectorState
    extends State<PredictiveBackGestureDetector>
    with WidgetsBindingObserver {
  PredictiveBackGesture _gesture = PredictiveBackGesture.idle;

  /// A gesture only scrubs a route that is on top and can be popped.
  bool get _enabled => widget.route.isCurrent && widget.route.popGestureEnabled;

  /// How open the route is right now, which is what a release has to continue
  /// from.
  double get _openness =>
      widget.route.animation?.value.clamp(0, 1) ?? 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.route.animation?.addStatusListener(_routeSettled);
  }

  @override
  void dispose() {
    widget.route.animation?.removeStatusListener(_routeSettled);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A gesture is only unresolved while the route keeps moving on its own; once
  /// the route settles, its animation drives the transition again. A commit the
  /// navigator refused never settles, so the release point stays available for
  /// the transition to undo the shrink.
  void _routeSettled(AnimationStatus status) {
    if (status != AnimationStatus.completed &&
        status != AnimationStatus.dismissed) {
      return;
    }
    if (!mounted || _gesture.phase == PredictiveBackPhase.idle) return;
    setState(() => _gesture = PredictiveBackGesture.idle);
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_enabled) return false;
    // The route restarts its animation from the top when a gesture commits, so
    // the point the finger released at is read before every hand-off.
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    _report(PredictiveBackPhase.update, released: _openness);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    widget.route.handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);
    _report(PredictiveBackPhase.update, released: _openness);
  }

  @override
  void handleCancelBackGesture() {
    final released = _openness;
    widget.route.handleCancelBackGesture();
    _report(PredictiveBackPhase.cancel, released: released);
  }

  @override
  void handleCommitBackGesture() {
    final released = _openness;
    widget.route.handleCommitBackGesture();
    _report(PredictiveBackPhase.commit, released: released);
  }

  void _report(PredictiveBackPhase phase, {required double released}) {
    if (!mounted) return;
    final gesture = PredictiveBackGesture(phase: phase, released: released);
    if (gesture == _gesture) return;
    setState(() => _gesture = gesture);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _gesture);
}
