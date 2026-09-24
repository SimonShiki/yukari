part of 'network_page_controller.dart';

extension NetworkPageActions on NetworkPageController {
  void createManually() => navigate('/networks/create', null);

  Future<void> importFromFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['toml'],
        dialogTitle: 'Select EasyTier Config File',
      );

      if (result.isEmpty) return;

      final file = result.first;
      if (file.path == null) {
        showMessage('Could not access the selected file.');
        return;
      }

      final content = await File(file.path!).readAsString();
      final network = parseEasyTierConfig(content);
      final key = network.networkName;

      if (networks.value.containsKey(key)) {
        showMessage('A network with the name "${network.networkName}" already exists.');
        return;
      }

      await addNetwork(key, network);
      showMessage('Network "${network.networkName}" imported successfully.');
    } catch (e) {
      showMessage('Failed to import config: ${e.toString()}');
    }
  }

  void scanQrCode() => showMessage('QR code scanning is coming soon.');

  void openInNewRoute(String id) {
    final network = networks.value[id];
    if (network == null || transitions.value[id] == InstanceStatus.starting) return;
    navigate(
      instances.value.containsKey(id) ? 'network-instance' : 'network-edit',
      network.networkName,
    );
  }

  void edit(String id) {
    final network = networks.value[id];
    if (network == null ||
        instances.value.containsKey(id) ||
        transitions.value[id] == InstanceStatus.starting) {
      return;
    }
    navigate('network-edit', network.networkName);
  }

  void log(String id) {
    final instance = instances.value[id];
    if (instance != null) showLog(instance);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    try {
      await reorderNetworks(oldIndex, newIndex);
    } catch (_) {
      if (!_disposed) showMessage('Could not reorder networks. Try again.');
    }
  }

  Future<void> toggle(String id, bool running) async {
    final network = networks.value[id];
    if (network == null ||
        _disposed ||
        deleting.value.contains(id) ||
        !loaded.value ||
        error.value != null ||
        transitions.value[id] == InstanceStatus.starting ||
        transitions.value[id] == InstanceStatus.stopping) {
      return;
    }
    if (running == instances.value.containsKey(id)) return;

    // Check TUN permission before starting a network that requires it
    if (running && !network.flags.noTun) {
      if (Platform.isAndroid) {
        final hasPermission = await requestTunPermission();
        if (!hasPermission) return;
      } else if (!canCreateTun()) {
        await showTunPermissionWarning(network);
        return;
      }
    }

    transitions.value[id] = running
        ? InstanceStatus.starting
        : InstanceStatus.stopping;
    transitions.set(transitions.value);
    if (running) {
      // The native run future completes when the instance exits, not on startup.
      unawaited(_runUntilStopped(id, network));
    } else {
      try {
        await _stop([network.networkName]);
      } catch (_) {
        transitions.value.remove(id);
        transitions.set(transitions.value);
        if (!_disposed) showMessage('Could not stop ${network.networkName}.');
      }
      if (_active) await refresh();
    }
  }

  Future<void> _runUntilStopped(String id, Network network) async {
    try {
      await _run(network);
      transitions.value.remove(id);
      transitions.set(transitions.value);
    } catch (_) {
      transitions.value[id] = InstanceStatus.failed;
      transitions.set(transitions.value);
      if (!_disposed) showMessage('Could not run ${network.networkName}.');
    } finally {
      if (_active && !_disposed) await refresh();
    }
  }

  Future<void> delete(String id) async {
    final network = networks.value[id];
    if (network == null ||
        _disposed ||
        transitions.value[id] == InstanceStatus.starting ||
        transitions.value[id] == InstanceStatus.stopping ||
        !deleting.value.add(id)) {
      return;
    }
    deleting.set(deleting.value);
    try {
      if (!await confirmDelete(network) || _disposed) return;
      // Stop first, including an instance started since the last status refresh.
      final current = await _collect(Map.of(networks.value));
      if (_disposed) return;
      if (current.containsKey(id)) await _stop([network.networkName]);
      if (_disposed) return;
      await deleteNetwork(id);
      instances.value.remove(id);
      instances.set(instances.value);
      transitions.value.remove(id);
      transitions.set(transitions.value);
    } catch (_) {
      if (!_disposed) {
        showMessage('Could not delete ${network.networkName}. Try again.');
      }
    } finally {
      deleting.value.remove(id);
      deleting.set(deleting.value);
    }
  }
}
