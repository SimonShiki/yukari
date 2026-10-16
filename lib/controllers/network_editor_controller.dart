import 'package:signals/signals.dart';

import '../models/network.dart';
import '../signals/networks.dart';
import 'network_editor_validator.dart';

class NetworkEditorController {
  NetworkEditorController({required this.name, required this.showMessage})
    : editing = signal(networks.value[name]!);

  final String name;
  final void Function(String message) showMessage;

  /// Working copy of the network, or null when [name] does not exist.
  final ReadonlySignal<Network> editing;

  late final networkName = computed(() => editing.value.networkName);
  late final dhcp = computed(() => editing.value.dhcp);

  final validator = _FormValidator();

  void dispose() {
    networkName.dispose();
    editing.dispose();
  }
}

class _FormValidator {
  _FormValidator();

  String? networkName(String? name) => validateNetworkName(name, index.peek());
}
