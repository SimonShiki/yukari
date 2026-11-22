part of 'share_document.dart';

final RegExp _invalidPathCharacters = RegExp(r'[?#\s]');
const int _maxPathLength = 256;
List<SharedPeer> _legacyPeer(Object? entry, String field) {
  if (entry is! Map<String, Object?>) _reject('$field is not an object');

  final host = entry['host'];
  if (host is! String || !shareableHost(host)) {
    _reject('$field has an invalid host');
  }
  final path = _sharedPath(entry['path'], field);
  try {
    if (path != null && Uri(host: host, path: path).path != path) {
      _reject('$field has an invalid path');
    }
  } on FormatException {
    _reject('$field has an invalid address');
  }

  final port = entry['port'];
  if (port is! int || port < 1 || port > 65535) {
    _reject('$field has an invalid port');
  }

  final names = entry['protocols'];
  if (names is! List<Object?> || names.isEmpty) {
    _reject('$field has no protocols');
  }
  final protocols = <NodeProtocol>[];
  for (final name in names) {
    final protocol = name is String ? _protocolNamed(name) : null;
    if (protocol == null) _reject('$field has an unknown protocol: $name');
    if (!protocols.contains(protocol)) protocols.add(protocol);
  }

  return [
    for (final protocol in protocols)
      SharedPeer(
        url: Uri(scheme: protocol.name, host: host, port: port, path: path),
        publicKey: _sharedText(entry['publicKey'], 'publicKey', _maxKeyLength),
      ),
  ];
}

/// A validated authority-relative path field, or null when it is absent.
String? _sharedPath(Object? value, String field) {
  if (value == null) return null;
  if (value is! String || !value.startsWith('/')) {
    _reject('$field path does not start with "/"');
  }
  if (value.length > _maxPathLength || _invalidPathCharacters.hasMatch(value)) {
    _reject('$field has an invalid path');
  }
  return value;
}

NodeProtocol? _protocolNamed(String name) =>
    NodeProtocol.values.asNameMap()[name];
