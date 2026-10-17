import 'dart:async';

import 'package:yukari/backend/system/service_control.dart';
import 'package:yukari/models/backend.dart';

/// A [ServiceControl] for tests: a supported service that answers as running,
/// or an unsupported platform that answers as unsupported.
///
/// The gates hold an answer open, so a test can observe what happens while an
/// action is still in flight, and [fail] makes every action throw once
/// released.
final class FakeServiceControl implements ServiceControl {
  FakeServiceControl({
    this.supported = true,
    this.stateGate,
    this.actionGate,
    this.fail = false,
  });

  @override
  String get dataDir => '/data';

  @override
  final bool supported;

  /// When set, [state] waits for it to complete first.
  final Completer<void>? stateGate;

  /// When set, every action waits for it to complete first.
  final Completer<void>? actionGate;

  /// Whether the actions throw once released.
  final bool fail;

  @override
  Future<ServiceState> state() async {
    await stateGate?.future;
    return supported ? ServiceState.running : ServiceState.unsupported;
  }

  @override
  Future<void> install({void Function(double? progress)? onProgress}) async {
    onProgress?.call(0.25);
    await actionGate?.future;
    // The page may be gone by now: this report must be dropped.
    onProgress?.call(0.75);
  }

  @override
  Future<void> uninstall() => _action();

  @override
  Future<void> start() => _action();

  @override
  Future<void> stop() => _action();

  Future<void> _action() async {
    await actionGate?.future;
    if (fail) throw StateError('stuck');
  }
}
