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

  /// Adds [peer], or replaces the peer with the same id.
  void addPeer(Node peer) {
    update((network) {
      final peers = [...network.nodes];
      final index = peers.indexWhere((existing) => existing.id == peer.id);
      if (index < 0) {
        peers.add(peer);
      } else {
        peers[index] = peer;
      }
      network.nodes = peers;
    });
    nodes.value = List.unmodifiable(working.peek()!.nodes);
  }

  /// Removes the peer stored under [id].
  void removePeer(String id) {
    update(
      (network) => network.nodes = [
        for (final peer in network.nodes)
          if (peer.id != id) peer,
      ],
    );
    nodes.value = List.unmodifiable(working.peek()!.nodes);
  }

  /// Adds [picked] as initial peers, as copies.
  void addBookmarks(Iterable<Bookmark> picked) {
    update((network) {
      final peers = [...network.nodes];
      for (final bookmark in picked) {
        if (peers.any((peer) => peer.id == bookmark.node.id)) continue;
        peers.add(bookmark.node.copy());
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
