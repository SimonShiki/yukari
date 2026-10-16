part of 'network_page_actions.dart';

/// Controller of the create-network page: the id, the store call, the
/// navigation and the `creating` flag, none of which belong to the widget.
class NetworkCreatorController {
  NetworkCreatorController({
    required this.navigate,
    required this.showMessage,
    Future<void> Function(String id, Network network)? add,
  }) : _add = add ?? saved.addNetwork;

  final void Function(String route) navigate;
  final void Function(String message) showMessage;
  final Future<void> Function(String id, Network network) _add;

  /// Whether a create request is in flight; both buttons are disabled then.
  final Signal<bool> creating = signal(false);

  bool _disposed = false;

  /// The saved networks' names, which the new name may not repeat.
  Iterable<String> get takenNames => saved.networkNames();

  /// Saves a network named [name] and opens its editor.
  Future<void> create({required String name, String? hostname}) async {
    if (creating.value || _disposed) return;
    creating.value = true;
    final host = hostname?.trim();
    final id = const Uuid().v4();
    try {
      await _add(
        id,
        Network()
          ..networkName = name.trim()
          ..hostname = host == null || host.isEmpty ? null : host,
      );
    } catch (error) {
      if (_disposed) return;
      creating.value = false;
      showMessage(l10n.value.networkCreateFailed('$error'));
      return;
    }
    if (_disposed) return;
    creating.value = false;
    navigate('/networks/edit/$id');
  }

  void dispose() {
    _disposed = true;
    creating.dispose();
  }
}
