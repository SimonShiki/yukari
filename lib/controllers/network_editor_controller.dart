import 'package:signals/signals.dart';

import '../models/network.dart';
import '../signals/networks.dart';
import '../utils/validator.dart';

/// Edits the saved network [id]. Pages validate input and only pass accepted
/// values to [update], which applies and saves them immediately.
class NetworkEditorController {
  NetworkEditorController({required this.id, required this.showMessage})
    : network = signal(networks.value[id]?.copy());

  final String id;
  final void Function(String message) showMessage;

  /// Working copy of the network, or null when [id] does not exist.
  final Signal<Network?> network;

  late final networkName = computed(() => network.value?.networkName);

  String? networkNameError(String value) =>
      validateNetworkName(value, networkNames(exceptId: id));

  Future<void> update(void Function(Network network) change) async {
    final current = network.peek();
    if (current == null) return;
    change(current);
    current.updatedAt = DateTime.now().toUtc();
    network.set(current, force: true);
    try {
      // Save a copy so later edits never mutate the saved state in place.
      await updateNetwork(id, current.copy());
    } catch (e) {
      showMessage('Failed to save: $e');
    }
  }

  void dispose() {
    networkName.dispose();
    network.dispose();
  }
}
