import 'package:signals/signals.dart';

/// Owns the signals and subscriptions created by a controller.
mixin SignalScope {
  final _cleanups = <void Function()>[];
  final _signalDisposers = <void Function()>[];

  Signal<T> own<T>(T value) => _track(signal<T>(value));
  Computed<T> derive<T>(T Function() compute) => _track(computed<T>(compute));

  S _track<S extends ReadonlySignal<Object?>>(S signal) {
    _signalDisposers.add(signal.dispose);
    return signal;
  }

  void addCleanup(void Function() cleanup) => _cleanups.add(cleanup);

  void disposeSignals() {
    for (final cleanup in _cleanups.reversed) {
      cleanup();
    }
    _cleanups.clear();
    for (final dispose in _signalDisposers.reversed) {
      dispose();
    }
    _signalDisposers.clear();
  }
}
