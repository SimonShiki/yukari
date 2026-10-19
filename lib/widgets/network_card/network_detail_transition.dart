import 'package:material_ui/material_ui.dart';

import 'detail_container.dart';
import 'predictive_back_gesture_detector.dart';

/// Wraps a detail route in Android's container transform: the page grows out of
/// the card that was tapped, and a back gesture shrinks it back into it.
///
/// The container follows the finger one to one, and a released gesture carries
/// the motion on from where it was released — it never jumps back to the full
/// page first.
class NetworkDetailTransition extends StatefulWidget {
  const NetworkDetailTransition({
    super.key,
    required this.origin,
    required this.animation,
    required this.gesture,
    required this.child,
  });

  /// How long a released gesture takes to settle. It matches the route's own
  /// transition duration, so the page and the route finish together.
  static const Duration settleDuration = Duration(milliseconds: 400);

  /// The card's rect on screen, or null when the route was opened without one,
  /// as a deep link is.
  final Rect? origin;

  /// The route's own animation: one while the page covers the window.
  final Animation<double> animation;

  final PredictiveBackGesture gesture;
  final Widget child;

  @override
  State<NetworkDetailTransition> createState() => _NetworkDetailTransitionState();
}

class _NetworkDetailTransitionState extends State<NetworkDetailTransition>
    with SingleTickerProviderStateMixin {
  /// The transform's one curve, read on a clock that runs from zero to one in
  /// the direction of travel: an opening grows along it and a closing shrinks
  /// along it. Driving both directions forwards is what makes a close repeat
  /// the open's timing instead of running its curve backwards.
  static const Curve _curve = Curves.easeInOutCubicEmphasized;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: NetworkDetailTransition.settleDuration,
  );

  /// How open the page is [progress] of the way through an opening.
  static double _opening(double progress) =>
      _curve.transform(progress.clamp(0, 1));

  /// How open the page is [progress] of the way through a closing.
  static double _closing(double progress) => 1 - _opening(progress);

  double _from = 1;
  double _to = 1;

  /// The route's own animation value when the settle started, which tells a
  /// refused pop (the route never moves) from one that is leaving.
  double _routeAtRelease = 1;

  /// Set when a commit was refused: the page came back out of the card and
  /// follows the route again as soon as the route moves.
  bool _refused = false;

  @override
  void didUpdateWidget(NetworkDetailTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gesture.phase == oldWidget.gesture.phase) return;
    switch (widget.gesture.phase) {
      case PredictiveBackPhase.commit:
        _settleTarget(0);
      case PredictiveBackPhase.cancel:
        _settleTarget(1);
      case PredictiveBackPhase.idle:
      case PredictiveBackPhase.update:
        _settle.stop();
    }
  }

  /// Runs the remaining motion on from the openness the finger released at.
  ///
  /// A commit keeps the full duration: the route plays its whole pop in that
  /// time, and a shorter settle would park the page in the card's slot while
  /// the route was still going. A cancel only travels back up, and the route's
  /// own animation scales its duration by that distance too.
  void _settleTarget(double target, {double? from}) {
    _from = from ?? widget.gesture.released;
    _to = target;
    _routeAtRelease = widget.animation.value;
    final remaining = _to == 0 ? 1.0 : (_to - _from).abs().clamp(0, 1);
    _settle.duration = NetworkDetailTransition.settleDuration * remaining;
    _settle.forward(from: 0).whenComplete(_settleFinished);
  }

  /// A commit the navigator refused leaves the route where it was, so the page
  /// has to come back out of the card instead of staying in it.
  void _settleFinished() {
    if (!mounted || _to != 0) return;
    if (widget.animation.value != _routeAtRelease) return;
    _refused = true;
    _settleTarget(1, from: 0);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  /// How far the page is out of the card after the settle has come [progress]
  /// of the way, from the released openness to the finish it heads for.
  double get _settledOpenness {
    final progress = _settle.value;
    return _to == 0
        ? _from * _closing(progress)
        : _from + (1 - _from) * _opening(progress);
  }

  /// How far the page is out of the card: zero at the card, one over the whole
  /// window.
  double _openness() {
    if (_refused) {
      // The refused pop's route sat still; once it moves, it is leaving after
      // all and its animation takes the transition back.
      if (widget.animation.value != _routeAtRelease) _refused = false;
      return _settledOpenness.clamp(0, 1);
    }
    return switch (widget.gesture.phase) {
      // The finger owns the container while it drags.
      PredictiveBackPhase.update => widget.animation.value.clamp(0, 1),
      PredictiveBackPhase.commit ||
      PredictiveBackPhase.cancel => _settledOpenness.clamp(0, 1),
      // A plain pop reads the same clock as the push, from the first frame the
      // route leaves the top of its animation.
      PredictiveBackPhase.idle =>
        widget.animation.status == AnimationStatus.reverse
            ? _closing(1 - widget.animation.value.clamp(0, 1)).clamp(0, 1)
            : _opening(widget.animation.value.clamp(0, 1)).clamp(0, 1),
    };
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.animation, _settle]),
    child: widget.child,
    builder: (context, child) {
      final card = widget.origin;
      final openness = _openness();
      if (card == null) {
        return DetailDissolve(openness: openness, child: child!);
      }
      return DetailContainer(
        origin: card,
        openness: openness,
        child: child!,
      );
    },
  );
}
