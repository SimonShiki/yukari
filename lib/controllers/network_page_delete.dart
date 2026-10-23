part of 'network_page_actions.dart';

/// The delete half of the networks page: one network from its row menu, and
/// every network the list selects.
extension NetworkPageDelete on NetworkPageController {
  /// Confirms, then deletes [id] and stops the instance it may have started.
  Future<void> delete(String id) async {
    final network = saved.networks.peek()[id];
    if (network == null) return;
    await _deleteAll(
      {id: network},
      failure: () => l10n.value.controllerDeleteFailed(network.networkName),
    );
  }

  /// Confirms, then deletes every selected network, stopping the ones that run
  /// first, exactly as [delete] does one at a time.
  ///
  /// A refused confirmation keeps the networks and the selection, so the
  /// action surface stays where the user left it.
  Future<void> deleteSelection() async {
    final targets = {
      for (final id in selection.orderedSelection)
        id: ?saved.networks.peek()[id],
    };
    if (targets.isEmpty) return;
    final deleted = await _deleteAll(
      targets,
      failure: () => l10n.value.controllerDeleteSelectedFailed,
    );
    // The page may be gone by now, and its selection with it.
    if (deleted && !isDisposed) selection.exit();
  }

  /// Confirms [targets] once, then stops the instances that run and deletes all
  /// of them; answers whether every one went.
  ///
  /// [failure] says what the user lost when the store refuses, so a single
  /// network can be named and a whole batch is reported as such.
  Future<bool> _deleteAll(
    Map<String, Network> targets, {
    required String Function() failure,
  }) async {
    if (targets.isEmpty || isDisposed) return false;
    final ids = targets.keys.toList();
    deleting.value = {...deleting.value, ...ids};
    try {
      if (!await confirmDelete(targets.values.toList())) return false;
      // An instance may have started since the last refresh.
      final names = [
        for (final id in (await activeBackend.collect(targets)).keys)
          targets[id]!.networkName,
      ];
      if (names.isNotEmpty) await activeBackend.stop(names);
      for (final id in ids) {
        await saved.deleteNetwork(id);
        // The store outlives this controller, so the deleted networks are
        // forgotten even if the page is gone.
        clearInstanceLogs(id);
      }
      forgetInstances(ids);
      if (isDisposed) return true;
      transitions.value = {...transitions.value}
        ..removeWhere((id, _) => targets.containsKey(id));
      return true;
    } catch (_) {
      if (!isDisposed) showMessage(failure());
      return false;
    } finally {
      if (!isDisposed) {
        deleting.value = {...deleting.value}..removeWhere(ids.contains);
      }
    }
  }
}
