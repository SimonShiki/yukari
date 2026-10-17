import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:signals/signals.dart';
import 'package:uuid/uuid.dart';

import '../bindings/easytier_ffi_native.dart' show parseConfig;
import '../models/models.dart';
import '../signals/instance_logs.dart';
import '../signals/instances.dart';
import '../signals/locale.dart';
import '../signals/networks.dart' as saved;
import '../utils/easytier_config_parser.dart';
import '../utils/easytier_config_serializer.dart';
import '../utils/file_save.dart';
import '../utils/validator.dart';
import 'network_instance_controller.dart';
import 'network_page_controller.dart';

part 'network_creator_controller.dart';
part 'network_page_export.dart';
part 'network_page_import.dart';

/// The actions the networks list and its detail pane invoke.
///
/// An extension, so the controller's state stays one job per file and the
/// actions only reach it through the controller's own API.
extension NetworkPageActions on NetworkPageController {
  /// Opens the create-network page.
  void createManually() => navigate('/networks/create', null);

  /// Opens the instance page while [id] runs, else its editor: what the wide
  /// layout's detail pane shows, reached by route on narrow windows.
  void openDetail(String id) => navigate(
    instances.value.containsKey(id) ? 'network-instance' : 'network-edit',
    id,
  );

  /// Opens the editor of [id], unless it is running or starting.
  ///
  /// On wide windows the detail pane is the editor, so it only selects; narrow
  /// windows navigate to the route.
  Future<void> edit(String id) async {
    if (instances.value.containsKey(id)) return;
    if (transitions.value[id] == NetworkTransition.starting) return;
    if (_paneIsOpen) {
      await select(id);
      return;
    }
    navigate('network-edit', id);
  }

  /// Opens the log view of [id], which only exists while it runs.
  ///
  /// On wide windows the detail pane is the instance page, so it selects the
  /// network and switches the pane to its logs tab; narrow windows navigate.
  Future<void> log(String id) async {
    if (!instances.value.containsKey(id)) return;
    if (_paneIsOpen) {
      // The selection dialog can outlive the page; a disposed controller
      // writes nothing.
      if (await select(id) && !isDisposed) {
        instanceTab.value = InstanceTab.logs;
      }
      return;
    }
    navigate('network-logs', id);
  }

  /// Selects [id], asking first when the editor that is leaving holds invalid
  /// input. Exactly one prompt per selection change.
  ///
  /// The wide detail pane always shows a network, so clearing the selection is
  /// a no-op there: a rebuilt list that re-emits "nothing selected" must not
  /// drop the pane or prompt to discard.
  Future<bool> select(String? id) async {
    if (id == null && _paneIsOpen) return true;
    if (id == selectedId.value) return true;
    if ((invalidInput?.call() ?? false) && !await confirmDiscard()) return false;
    // The dialog can outlive the page, so the answer is only applied while
    // there is still a selection signal to hold it.
    if (isDisposed) return false;
    selectedId.value = id;
    return true;
  }

  /// Whether the list is beside its detail pane.
  bool get _paneIsOpen => isWide?.call() ?? false;

  /// Moves the network at [oldIndex] to [newIndex].
  Future<void> reorder(int oldIndex, int newIndex) async {
    try {
      await saved.reorderNetworks(oldIndex, newIndex);
    } catch (_) {
      showMessage(l10n.value.controllerReorderFailed);
    }
  }

  /// Starts [id] when [start], else stops it.
  ///
  /// A `failed` marker does not block a retry: the request is over, and the
  /// card keeps its toggle enabled so the user can try again.
  Future<void> toggle(String id, bool start) async {
    final network = saved.networks.peek()[id];
    final transition = transitions.value[id];
    if (network == null ||
        isDisposed ||
        deleting.value.contains(id) ||
        !loaded.value ||
        refreshError.value != null ||
        transition == NetworkTransition.starting ||
        transition == NetworkTransition.stopping ||
        instances.value.containsKey(id) == start) {
      return;
    }
    start ? await _start(id, network) : await _stop(id, network);
  }

  /// Confirms, then deletes [id] and stops the instance it may have started.
  Future<void> delete(String id) async {
    final network = saved.networks.peek()[id];
    if (network == null || isDisposed) return;
    deleting.value = {...deleting.value, id};
    try {
      if (!await confirmDelete(network)) return;
      // An instance may have started since the last refresh.
      if ((await activeBackend.collect({id: network}))[id] != null) {
        await activeBackend.stop([network.networkName]);
      }
      await saved.deleteNetwork(id);
      // The store outlives this controller, so the deleted network is
      // forgotten even if the page is gone.
      clearInstanceLogs(id);
      forgetInstances([id]);
      if (!isDisposed) transitions.value = {...transitions.value}..remove(id);
    } catch (_) {
      if (!isDisposed) {
        showMessage(l10n.value.controllerDeleteFailed(network.networkName));
      }
    } finally {
      if (!isDisposed) deleting.value = {...deleting.value}..remove(id);
    }
  }

  /// Imports a TOML config the user picked as a new network.
  Future<void> importFromFile() async {
    final picked = await readPickedConfig(pickConfig, showMessage);
    if (picked == null) return;
    try {
      final network = parseImportedConfig(picked.content, validateConfig);
      await saved.addNetwork(const Uuid().v4(), network);
    } on _InvalidConfig catch (error) {
      showMessage(l10n.value.controllerImportInvalid(picked.name, error.message));
    } catch (error) {
      showMessage(l10n.value.controllerImportFailed('$error'));
    }
  }

  Future<void> _start(String id, Network network) async {
    final limit = activeBackend.maxInstances;
    if (limit != null && instances.value.length >= limit) {
      showMessage(
        limit == 1
            ? l10n.value.controllerOneNetwork
            : l10n.value.controllerNetworkLimit('$limit'),
      );
      return;
    }
    switch (await activeBackend.tunAccess(network)) {
      case TunAccess.denied:
        return;
      case TunAccess.elevationRequired:
        await showTunPermissionWarning(network);
        return;
      case TunAccess.granted:
        break;
    }
    if (isDisposed) return;
    transitions.value = {...transitions.value, id: NetworkTransition.starting};
    clearInstanceLogs(id);
    try {
      await activeBackend.start(id, network);
    } catch (error) {
      if (!isDisposed) {
        transitions.value = {
          ...transitions.value,
          id: NetworkTransition.failed,
        };
        showMessage(
          l10n.value.controllerNetworkRun(network.networkName, '$error'),
        );
      }
    }
    await _refreshWhenActive();
  }

  Future<void> _stop(String id, Network network) async {
    transitions.value = {...transitions.value, id: NetworkTransition.stopping};
    try {
      await activeBackend.stop([network.networkName]);
      // The store outlives this controller, so a settled stop is reflected
      // even if the page is gone.
      forgetInstances([id]);
    } catch (error) {
      if (!isDisposed) {
        transitions.value = {...transitions.value}..remove(id);
        showMessage(
          l10n.value.controllerNetworkStop(network.networkName, '$error'),
        );
      }
    }
    await _refreshWhenActive();
  }

  Future<void> _refreshWhenActive() async {
    if (active && !isDisposed) await refresh();
  }
}

/// A picked config that EasyTier or the editor's rules reject.
class _InvalidConfig implements Exception {
  _InvalidConfig(this.message);

  final String message;
}
