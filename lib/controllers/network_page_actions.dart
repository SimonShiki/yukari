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
      // Imported files are untrusted: let EasyTier reject invalid configs.
      native.parseConfig(content);
      final network = parseEasyTierConfig(content);

      final error =
          validateNetworkName(network.networkName, networkNames()) ??
          validateNetwork(network);
      if (error != null) {
        showMessage('Cannot import "${network.networkName}": $error');
        return;
      }

      await addNetwork(const Uuid().v4(), network);
    } catch (e) {
      showMessage('Failed to import config: ${e.toString()}');
    }
  }

  void scanQrCode() => showMessage('QR code scanning is coming soon.');

  void openInNewRoute(String id) {
    final network = networks.value[id];
    if (network == null || transitions.value[id] == InstanceStatus.starting)
      return;
    navigate(
      instances.value.containsKey(id) ? 'network-instance' : 'network-edit',
      id,
    );
  }

  void edit(String id) {
    final network = networks.value[id];
    if (network == null ||
        instances.value.containsKey(id) ||
        transitions.value[id] == InstanceStatus.starting) {
      return;
    }
    navigate('network-edit', id);
  }

  void log(String id) {
    if (instances.value.containsKey(id)) navigate('network-logs', id);
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

    final backend = _backend;
    if (running) {
      if (backend.maxInstances case final limit?
          when instances.value.length >= limit) {
        showMessage(
          limit == 1
              ? 'Only one network can run at a time.'
              : 'Only $limit networks can run at a time.',
        );
        return;
      }
      switch (await backend.tunAccess(network)) {
        case TunAccess.granted:
          break;
        case TunAccess.denied:
          return;
        case TunAccess.elevationRequired:
          await showTunPermissionWarning(network);
          return;
      }
      if (_disposed) return;
    }

    transitions.value[id] = running
        ? InstanceStatus.starting
        : InstanceStatus.stopping;
    transitions.set(transitions.value);
    try {
      if (running) {
        clearInstanceLogs(id);
        await backend.start(id, network);
      } else {
        await backend.stop([network.networkName]);
        transitions.value.remove(id);
        transitions.set(transitions.value);
      }
    } catch (e) {
      if (running) {
        transitions.value[id] = InstanceStatus.failed;
      } else {
        transitions.value.remove(id);
      }
      transitions.set(transitions.value);
      if (!_disposed) {
        showMessage(
          'Could not ${running ? 'run' : 'stop'} ${network.networkName}: $e',
        );
      }
    }
    if (_active && !_disposed) await refresh();
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
      final current = await _backend.collect(Map.of(networks.value));
      if (_disposed) return;
      if (current.containsKey(id)) await _backend.stop([network.networkName]);
      if (_disposed) return;
      await deleteNetwork(id);
      clearInstanceLogs(id);
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
