part of 'network_editor_controller.dart';

/// The editor's bound primitives: one per field and one per peer row, each
/// written only when its own value changes.
extension NetworkEditorSignals on NetworkEditorController {
  /// Whether [node] has a saved bookmark: one primitive per peer row, so a
  /// bookmark change rebuilds that row's button only.
  ReadonlySignal<bool> bookmarkedNode(Node node) {
    final key = nodeKey(node);
    final existing = _bookmarkFields[key];
    if (existing != null) return existing.signal;
    final created = _NodeFlag(
      signal(
        saved.bookmarks.peek().any(
          (bookmark) => sameNode(bookmark.node, node),
        ),
      ),
      node,
    );
    _bookmarkFields[key] = created;
    return created.signal;
  }

  /// A small primitive of the working copy, cached by [key].
  ///
  /// Fields bind these instead of the whole network, and the signal behind one
  /// is written only when that field's value actually changes. [fallback]
  /// covers the unknown-id state, and one [key] must be used for one field
  /// only.
  ReadonlySignal<T> select<T>(
    String key,
    T Function(Network) read,
    T fallback,
  ) {
    final cached = _selects[key];
    if (cached != null) return cached as ReadonlySignal<T>;
    final network = working.peek();
    final created = _FieldSignal<T>(
      signal(network == null ? fallback : read(network)),
      read,
      fallback,
    );
    _fields.add(created);
    _selects[key] = created.signal;
    return created.signal;
  }
}

/// One field's primitive, its reader and the value to show without a network.
class _FieldSignal<T> {
  _FieldSignal(this.signal, this.read, this.fallback);

  final Signal<T> signal;
  final T Function(Network) read;
  final T fallback;
}

/// One peer row's bookmark flag.
class _NodeFlag {
  _NodeFlag(this.signal, this.node);

  final Signal<bool> signal;
  final Node node;
}
