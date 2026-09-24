import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../models/network_builder.dart';
import '../signals/networks.dart';

class NetworkEditorController {
  NetworkEditorController({
    required String networkName,
    required this.showMessage,
    required this.showError,
  }) : _networkName = signal(networkName) {
    _loadNetwork();
    _unsubscribe = effect(() {
      networks.value; // Subscribe to changes
      _networkName.value; // Subscribe to network name changes
      _loadNetwork();
    });
  }

  final Signal<String> _networkName;
  String get networkName => _networkName.value;
  final ValueChanged<String> showMessage;
  final void Function(String title, String message) showError;

  late final void Function() _unsubscribe;

  final builder = signal<NetworkBuilder?>(null);
  final loaded = signal(false);
  final saving = signal(false);

  late final networkNotFound = computed(() => loaded.value && builder.value == null);

  void switchNetwork(String name) {
    _networkName.value = name;
  }

  void _loadNetwork() {
    final network = networks.value[_networkName.value];
    loaded.value = false;
    if (network != null) {
      builder.value = NetworkBuilder.from(network);
    } else {
      builder.value = null;
    }
    loaded.value = true;
  }

  Future<void> save() async {
    if (builder.value == null || saving.value) return;

    saving.value = true;

    try {
      final network = builder.value!.build();
      await updateNetwork(_networkName.value, network);
      showMessage('Network saved successfully');
    } on ArgumentError catch (e) {
      showError('Validation Error', e.toString());
    } catch (e) {
      showMessage('Failed to save: $e');
    } finally {
      saving.value = false;
    }
  }

  void dispose() {
    _unsubscribe();
    _networkName.dispose();
  }
}
