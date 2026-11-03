part of 'networks.dart';

final _pendingNetworkEdits = <String, _NetworkEdit>{};
final _networkEditWrites = <String, ({Network network, Future<bool> done})>{};

/// Whether accepted edits are waiting for their timer or disk write.
bool get hasPendingNetworkEdits =>
    _pendingNetworkEdits.isNotEmpty || _networkEditWrites.isNotEmpty;

/// The latest accepted edit of [id], or its saved configuration.
Network? latestNetwork(String id) =>
    _pendingNetworkEdits[id]?.network ??
    _networkEditWrites[id]?.network ??
    _networks.peek()[id];

/// Saves [network] after 300 ms without another edit to [id].
/// Calls [onError] once if that save fails; saved state rolls back as usual.
void scheduleNetworkEdit(
  String id,
  Network network, {
  required void Function(Object error) onError,
}) {
  _discardNetworkEdit(id);
  final edit = _NetworkEdit(network, onError);
  _pendingNetworkEdits[id] = edit;
  edit.timer = Timer(const Duration(milliseconds: 300), () {
    unawaited(flushNetworkEdits(id));
  });
}

/// Saves pending edits immediately and waits for their writes, for [id] or all
/// networks. Returns false if a write failed; its editor reports the error.
/// Failed edits stay pending for a later flush.
Future<bool> flushNetworkEdits([String? id]) async {
  final pending = _pendingNetworkEdits.entries
      .where((entry) => id == null || entry.key == id)
      .toList();
  for (final entry in pending) {
    _discardNetworkEdit(entry.key);
    final write = _writeNetworkEdit(entry.key, entry.value);
    _networkEditWrites[entry.key] = (network: entry.value.network, done: write);
    unawaited(
      write.whenComplete(() {
        if (identical(_networkEditWrites[entry.key]?.done, write)) {
          _networkEditWrites.remove(entry.key);
        }
      }),
    );
  }
  final writes = _networkEditWrites.entries
      .where((entry) => id == null || entry.key == id)
      .map((entry) => entry.value.done)
      .toList();
  return (await Future.wait(writes)).every((saved) => saved);
}

Future<bool> _writeNetworkEdit(String id, _NetworkEdit edit) async {
  try {
    await updateNetwork(id, edit.network.copy());
    return true;
  } catch (error) {
    if (_networks.peek().containsKey(id) &&
        !_pendingNetworkEdits.containsKey(id) &&
        identical(_networkEditWrites[id]?.network, edit.network)) {
      _pendingNetworkEdits[id] = edit;
    }
    edit.onError(error);
    return false;
  }
}

void _discardNetworkEdit(String id) =>
    _pendingNetworkEdits.remove(id)?.timer.cancel();

final class _NetworkEdit {
  _NetworkEdit(this.network, this.onError);

  final Network network;
  final void Function(Object error) onError;
  late final Timer timer;
}
