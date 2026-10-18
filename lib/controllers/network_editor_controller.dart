import 'dart:async';

import 'package:signals/signals.dart';

import '../constants/builtin_bookmarks.dart';
import 'package:yukari_core/models/models.dart';
import '../signals/backend.dart' as backends;
import '../signals/bookmarks.dart' as saved;
import '../signals/locale.dart';
import '../signals/networks.dart' as stored;
import '../utils/crypto_utils.dart';

part 'network_editor_signals.dart';

part 'network_editor_lists.dart';

/// Which of a network's two listener lists a list editor edits.
enum ListenerList { local, mapped }

/// Controller of the network editor: a deep working copy of one saved network,
/// saved on every accepted edit.
///
/// The fields bind small primitives of the copy through [select] rather than
/// the copy itself, so typing in one field rebuilds one segment. The
/// secure-mode and VPN-portal actions live in `network_editor_security.dart`.
class NetworkEditorController {
  NetworkEditorController({
    required this.id,
    required this.showMessage,
    List<Bookmark>? sharedBookmarks,
  }) : sharedBookmarks = sharedBookmarks ?? builtinBookmarks {
    working.value = stored.networks.value[id]?.copy();
    // Started eagerly, so every bound primitive follows the working copy.
    _stopFields = effect(() {
      final network = working.value;
      for (final field in _fields) {
        final next = network == null ? field.fallback : field.read(network);
        if (field.signal.peek() != next) field.signal.value = next;
      }
    });
    _stopBookmarks = effect(() {
      final savedBookmarks = saved.bookmarks.value;
      for (final entry in _bookmarkFields.entries) {
        final next = savedBookmarks.any(
          (bookmark) => sameNode(bookmark.node, entry.value.node),
        );
        if (entry.value.signal.peek() != next) entry.value.signal.value = next;
      }
    });
  }

  /// Key of the network in the saved network collection.
  final String id;

  /// Reports a failed save; the edit on screen stays.
  final void Function(String message) showMessage;

  /// A deep, independent copy of the saved network, or null for an unknown id.
  final Signal<Network?> working = signal(null);

  /// Whether the saved network is gone, so the page shows "not found".
  late final ReadonlySignal<bool> missing = computed(
    () => working.value == null,
  );

  /// The active backend's kind: the app-wide signal, so the startup section
  /// follows a backend switch.
  ReadonlySignal<BackendKind> get backendKind => backends.backendKind;

  /// The initial peers, so the peer rows rebuild only when a peer changes.
  late final Signal<List<Node>> nodes = signal(
    working.value?.nodes ?? const [],
  );

  /// The listeners, and the mapped listeners, for their list editors.
  late final Signal<List<Uri>> listeners = signal(
    working.value?.listeners ?? const [],
  );
  late final Signal<List<Uri>> mappedListeners = signal(
    working.value?.mappedListeners ?? const [],
  );

  final _fields = <_FieldSignal<Object?>>[];
  final _selects = <String, ReadonlySignal<Object?>>{};
  final _bookmarkFields = <(String host, int port), _NodeFlag>{};
  bool _disposed = false;

  /// Pushes every bound primitive, but only when its own value changed.
  ///
  /// A `computed` would notify on every change of the working copy, whatever
  /// its value, so each field gets a plain signal that is written only on a
  /// real change: a keystroke then rebuilds one segment (AGENTS.md § 2).
  late final void Function() _stopFields;

  /// The same push for the peer rows' bookmark flags.
  late final void Function() _stopBookmarks;

  /// The name the app bar shows; one primitive, so only the title rebuilds.
  ReadonlySignal<String> get name => select('name', (n) => n.networkName, '');

  /// Whether this controller has been disposed.
  bool get isDisposed => _disposed;

  /// The other networks' names, which this one's name may not repeat.
  Iterable<String> get otherNames => stored.networkNames(exceptId: id);

  /// The bundled shared nodes, which the empty-peers notice offers.
  ///
  /// Injectable, so the notice's "no public nodes" branch is reachable.
  final List<Bookmark> sharedBookmarks;

  /// The bookmarks a peer can be picked from: the shared nodes, then the
  /// user's own.
  List<Bookmark> get pickableBookmarks => [
    ...sharedBookmarks,
    ...saved.bookmarks.value,
  ];

  /// Applies [change] to the working copy, stamps it, notifies and persists a
  /// copy, so later edits cannot corrupt the stored value.
  void update(void Function(Network) change) {
    final current = working.value;
    if (current == null) return;
    final next = current.copy();
    change(next);
    next.updatedAt = DateTime.now().toUtc();
    working.value = next;
    unawaited(_persist(next));
  }

  /// Fills the optional network secret with a fresh random one.
  void generateSecret() => update((n) => n.networkSecret = generateSecretKey());

  /// Saves [node] as a bookmark, or removes the bookmark that covers it.
  Future<void> toggleBookmark(Node node) async {
    final existing = saved.bookmarkFor(node);
    try {
      if (existing == null) {
        await saved.addBookmark(
          Bookmark(id: node.id, node: node.copy(), name: node.id),
        );
        showMessage(l10n.value.bookmarksSaved);
      } else {
        await saved.deleteBookmark(existing.id);
        showMessage(l10n.value.bookmarksRemoved);
      }
    } catch (error) {
      showMessage(l10n.value.bookmarksSaveFailed('$error'));
    }
  }

  void dispose() {
    _disposed = true;
    _stopFields();
    _stopBookmarks();
    for (final field in _fields) {
      field.signal.dispose();
    }
    _fields.clear();
    _selects.clear();
    for (final flag in _bookmarkFields.values) {
      flag.signal.dispose();
    }
    _bookmarkFields.clear();
    for (final signal in <ReadonlySignal<Object?>>[
      working,
      missing,
      nodes,
      listeners,
      mappedListeners,
    ]) {
      signal.dispose();
    }
  }

  Future<void> _persist(Network network) async {
    try {
      await stored.updateNetwork(id, network.copy());
    } catch (error) {
      showMessage(l10n.value.controllerSave('$error'));
    }
  }

}
