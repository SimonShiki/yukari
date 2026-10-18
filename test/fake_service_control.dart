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
    this.current = ServiceState.running,
    this.stateGate,
    this.actionGate,
    this.fail = false,
  });

  @override
  String get dataDir => '/data';

  @override
  final bool supported;

  /// The state [state] answers for a supported service; [start] and [stop]
  /// move it like the service they stand for.
  ServiceState current;

  /// The actions that ran, in order.
  final List<String> calls = [];

  /// When set, [state] waits for it to complete first.
  final Completer<void>? stateGate;

  /// When set, every action waits for it to complete first.
  final Completer<void>? actionGate;

  /// Whether the actions throw once released.
  final bool fail;

  @override
  Future<ServiceState> state() async {
    await stateGate?.future;
    return supported ? current : ServiceState.unsupported;
  }

  @override
  Future<void> install({void Function(double? progress)? onProgress}) async {
    calls.add('install');
    onProgress?.call(0.25);
    await actionGate?.future;
    // The page may be gone by now: this report must be dropped.
    onProgress?.call(0.75);
  }

  @override
  Future<void> uninstall() => _action('uninstall');

  @override
  Future<void> start() async {
    await _action('start');
    current = ServiceState.running;
  }

  @override
  Future<void> stop() async {
    await _action('stop');
    current = ServiceState.stopped;
  }

  Future<void> _action(String name) async {
    calls.add(name);
    await actionGate?.future;
    if (fail) throw StateError('stuck');
  }
}
