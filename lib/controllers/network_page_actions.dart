part of 'network_page_controller.dart';

extension NetworkPageActions on NetworkPageController {
  void createManually() => navigate('/networks/create', null);

  Future<void> importFromFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['toml'],
        dialogTitle: l10n.value.controllerSelectConfig,
      );

      if (result.isEmpty) return;

      final file = result.first;
      if (file.path == null) {
        showMessage(l10n.value.controllerFileUnavailable);
        return;
      }

      final content = await File(file.path!).readAsString();
      // Imported files are untrusted: let EasyTier reject invalid configs.
      native.parseConfig(content);
      final network = parseEasyTierConfig(content);

      final error =
          validateNetworkName(network.networkName, index.peek()) ??
          validateNetwork(network);
      if (error != null) {
        showMessage(
          l10n.value.controllerImportInvalid(network.networkName, error),
        );
        return;
      }

      addNetwork(network.networkName, network);
    } catch (e) {
      showMessage(l10n.value.controllerImportFailed(e.toString()));
    }
  }

  void scanQrCode() => showMessage(l10n.value.controllerQrComing);

  void openInNewRoute(String name) {
    final network = networks[name];
    if (network == null || transitions.value[name] == InstanceStatus.starting) {
      return;
    }
    navigate(
      instances.value.containsKey(name) ? 'network-instance' : 'network-edit',
      name,
    );
  }

  void edit(String name) {
    final network = networks.value[name];
    if (network == null ||
        instances.value.containsKey(name) ||
        transitions.value[name] == InstanceStatus.starting) {
      return;
    }
    navigate('network-edit', name);
  }

  void log(String name) {
    if (instances.value.containsKey(name)) navigate('network-logs', name);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    try {
      reorderIndex(oldIndex, newIndex);
    } catch (_) {
      if (!_disposed) showMessage(l10n.value.controllerReorderFailed);
    }
  }

  Future<void> toggle(String name, bool running) async {
    final network = networks[name];
    if (network == null ||
        _disposed ||
        deleting.value.contains(name) ||
        !loaded.value ||
        error.value != null ||
        transitions.value[name] == InstanceStatus.starting ||
        transitions.value[name] == InstanceStatus.stopping) {
      return;
    }
    if (running == instances.value.containsKey(id)) return;

    final backend = _backend;
    if (running) {
      if (backend.maxInstances case final limit?
          when instances.value.length >= limit) {
        showMessage(
          limit == 1
              ? l10n.value.controllerOneNetwork
              : l10n.value.controllerNetworkLimit(limit.toString()),
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
          running
              ? l10n.value.controllerNetworkRun(
                  network.networkName,
                  e.toString(),
                )
              : l10n.value.controllerNetworkStop(
                  network.networkName,
                  e.toString(),
                ),
        );
      }
    }
    if (_active && !_disposed) await refresh();
  }

  Future<void> delete(String name) async {
    final network = networks[name];
    if (network == null ||
        _disposed ||
        transitions.value[name] == InstanceStatus.starting ||
        transitions.value[name] == InstanceStatus.stopping ||
        !deleting.value.add(name)) {
      return;
    }
    deleting.set(deleting.value);
    try {
      if (!await confirmDelete(network) || _disposed) return;
      // Stop first, including an instance started since the last status refresh.
      final current = await _backend.collect(Map.of(networks.value));
      if (_disposed) return;
      if (current.containsKey(name)) await _backend.stop([network.networkName]);
      if (_disposed) return;
      removeNetwork(name);
      clearInstanceLogs(name);
      instances.value.remove(name);
      instances.set(instances.value);
      transitions.value.remove(name);
      transitions.set(transitions.value);
    } catch (_) {
      if (!_disposed) {
        showMessage(l10n.value.controllerDeleteFailed(network.networkName));
      }
    } finally {
      deleting.value.remove(name);
      deleting.set(deleting.value);
    }
  }
}
