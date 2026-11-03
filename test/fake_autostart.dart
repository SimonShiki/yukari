import 'dart:async';

import 'package:yukari/system/autostart.dart';

/// An [Autostart] that records what the OS was asked to do and can misbehave.
final class FakeAutostart implements Autostart {
  FakeAutostart({
    this.supported = true,
    this.refuse = false,
    this.refuseDisable = false,
    this.enableGate,
  });

  @override
  final bool supported;

  /// Whether the OS rejects every change.
  final bool refuse;

  /// Whether the OS rejects disabling the app.
  bool refuseDisable;

  /// When set, an enable waits for it to complete first.
  Completer<void>? enableGate;

  /// The changes the OS accepted, in order.
  final applied = <bool>[];

  /// Every change attempted, including the refused and pending ones.
  int attempts = 0;

  /// The state the OS ended up in, or null before it accepted anything.
  bool? state;

  @override
  Future<void> setEnabled(bool enabled) async {
    attempts++;
    if (enabled) await enableGate?.future;
    if (refuse || (!enabled && refuseDisable)) {
      throw StateError('the OS refused the change');
    }
    applied.add(enabled);
    state = enabled;
  }
}
