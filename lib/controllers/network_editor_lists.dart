part of 'network_editor_controller.dart';

/// The working copy's lists, edited in place: the initial peers, the picked
/// bookmarks and the two listener lists.
extension NetworkEditorLists on NetworkEditorController {
  /// Adds a listener, or replaces [previous] at its position.
  void setListener(ListenerList list, Uri listener, {Uri? previous}) {
    update((network) {
      final values = [..._uris(network, list)];
      final index = previous == null ? -1 : values.indexOf(previous);
      if (index < 0) {
        values.add(listener);
      } else {
        values[index] = listener;
      }
      _write(network, list, values);
    });
    _syncShown(list);
  }

  /// Removes [listener] from [list].
  void removeListener(ListenerList list, Uri listener) {
    update(
      (network) => _write(network, list, [
        for (final value in _uris(network, list))
          if (value != listener) value,
      ]),
    );
    _syncShown(list);
  }

  /// Adds [peer], or replaces the peer stored under [previousName] at its
  /// position: an edit may change the name itself. Without [previousName], a
  /// peer with the same name is replaced.
  void setPeer(Node peer, {String? previousName}) {
    update((network) {
      final peers = [...network.nodes];
      final name = previousName ?? peer.name;
      final index = peers.indexWhere((existing) => existing.name == name);
      if (index < 0) {
        peers.add(peer);
      } else {
        peers[index] = peer;
      }
      network.nodes = peers;
    });
    nodes.value = List.unmodifiable(working.peek()!.nodes);
  }

  /// Removes the peer stored under [name].
  void removePeer(String name) {
    update(
      (network) => network.nodes = [
        for (final peer in network.nodes)
          if (peer.name != name) peer,
      ],
    );
    nodes.value = List.unmodifiable(working.peek()!.nodes);
  }

  /// Adds [picked] as initial peers, as copies.
  void addBookmarks(Iterable<Bookmark> picked) {
    update((network) {
      final peers = [...network.nodes];
      for (final bookmark in picked) {
        if (peers.any((peer) => sameNode(peer, bookmark.node))) continue;
        peers.add(copyNodeForNetwork(bookmark.node, peers));
      }
      network.nodes = peers;
    });
    nodes.value = List.unmodifiable(working.peek()!.nodes);
  }

  List<Uri> _uris(Network network, ListenerList list) =>
      list == ListenerList.local ? network.listeners : network.mappedListeners;

  void _write(Network network, ListenerList list, List<Uri> values) {
    if (list == ListenerList.local) {
      network.listeners = values;
    } else {
      network.mappedListeners = values;
    }
  }

  void _syncShown(ListenerList list) {
    final target = list == ListenerList.local ? listeners : mappedListeners;
    target.value = List.unmodifiable(_uris(working.peek()!, list));
  }
}
