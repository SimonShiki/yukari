import 'package:signals/signals.dart';

import '../models/models.dart';

/// Private backing signal for the global backend configuration.
/// Use [backend] for readonly access and [updateBackend] for mutations.
final Signal<Backend> _backend = signal<Backend>(Backend());

/// Global backend configuration state.
///
/// This signal holds the current backend configuration for the application.
///
/// **Initialization**: Initialized with a default [Backend] instance.
///
/// **Mutation**: Use [updateBackend] to change the backend configuration.
///
/// **Read**: Access via [backend.value] or subscribe in effects/computed signals.
///
/// Consumers should not mutate the backend directly; use the provided mutation API.
ReadonlySignal<Backend> get backend => _backend;

/// Update the global backend configuration.
///
/// This is the only supported way to mutate the backend signal.
/// Notifies all subscribers of the change.
void updateBackend(Backend newBackend) {
  _backend.value = newBackend;
}
