import 'dart:convert';

import 'package:yukari_core/models/node.dart';

import 'share_configs.dart';

/// The share format version [ShareDocument.encode] writes; a document from a
/// newer version is refused rather than guessed at.
const int shareDocumentVersion = 2;

/// The media type a share document carries when it leaves the app.
const String shareContentType = 'application/vnd.yukari.share+json';

/// The largest document content [ShareDocument.decode] accepts, in bytes.
const int shareMaxBytes = 64 * 1024;

/// The most peers a share document may carry.
const int shareMaxPeers = 64;

/// The longest name a share document may carry.
///
/// A sender clamps a name to this before encoding, so the number has to match
/// the limit the validator enforces.
const int shareMaxNameLength = 128;
const int _maxHostLength = 253;
const int _maxPathLength = 256;
const int _maxKeyLength = 512; // The longest secret or public key.

final RegExp _invalidHostCharacters = RegExp(r'[\s/@?#%]');
final RegExp _invalidPathCharacters = RegExp(r'[?#\s]');

/// Whether a shared document describes a whole network or a single node.
enum ShareKind { network, node }

/// One peer of a shared network, or the single peer of a shared node.
final class SharedPeer {
  const SharedPeer({required this.url, this.publicKey});

  final Uri url;
  final String? publicKey;

  String get address => url.toString();

  Map<String, Object?> toJson() => {
    'url': url.toString(),
    if (publicKey != null) 'publicKey': publicKey,
  };
}

/// The shareable subset of a saved network or node.
///
/// A document carries only what the receiver needs: a network's name, its
/// secret, its peers and, when the sender chose to include them, its
/// non-essential config, or a single node and its name. [encode] writes the
/// compact, versioned JSON a QR payload or the clipboard carries; a channel
/// may compress it, and [decode] reads the JSON back.
///
/// Version 2 carries full peer URLs. Version 1 peers are accepted on import
/// and expanded into one URL per protocol.
final class ShareDocument {
  const ShareDocument({
    required this.kind,
    required this.peers,
    this.name,
    this.secret,
    this.configs,
  });

  final ShareKind kind;

  /// A network's name, or the bookmark name of the shared node; absent when
  /// that node has no name.
  final String? name;

  /// The network's secret; absent from a node share, or when it has none.
  final String? secret;

  /// The network's non-essential config, when the sender shared it; absent
  /// from a node share, and from a network that runs at the import defaults.
  final SharedConfigs? configs;

  final List<SharedPeer> peers;

  bool get hasSecret => secret != null;

  /// The document as the compact JSON a share channel carries.
  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() => {
    'v': shareDocumentVersion,
    'kind': kind.name,
    if (name != null) 'name': name,
    if (secret != null) 'secret': secret,
    if (configs != null) 'configs': configs!.toJson(),
    'peers': [for (final peer in peers) peer.toJson()],
  };

  /// Parses untrusted [content], rejecting anything malformed.
  static ShareDocument decode(String content) => decodeRoot(parseRoot(content));

  /// The JSON object [content] holds, checked for the share size cap and shape.
  ///
  /// A payload arrives from a QR code of unknown origin, so the size cap and
  /// the object shape are checked before any field is read; a bundle and a
  /// single document share this step.
  static Map<String, Object?> parseRoot(String content) {
    if (utf8.encode(content).length > shareMaxBytes) {
      _reject('Share document is larger than $shareMaxBytes bytes');
    }

    final Object? root;
    try {
      root = jsonDecode(content);
    } on FormatException catch (error) {
      _reject('Not valid JSON: ${error.message}');
    }
    if (root is! Map<String, Object?>) {
      _reject('Expected a share document object');
    }
    return root;
  }

  /// The document the decoded JSON [root] describes.
  ///
  /// A document arrives from a QR code of unknown origin, so every field is
  /// checked and a bad one throws a [FormatException] instead of being half
  /// accepted.
  static ShareDocument decodeRoot(Map<String, Object?> root) {
    final version = root['v'];
    if (version != 1 && version != shareDocumentVersion) {
      _reject('Unsupported share format version: $version');
    }
    final kind = switch (root['kind']) {
      'network' => ShareKind.network,
      'node' => ShareKind.node,
      final Object? other => _reject('Unknown share kind: $other'),
    };
    final name = _sharedText(root['name'], 'name', shareMaxNameLength);
    final secret = _sharedText(root['secret'], 'secret', _maxKeyLength);
    final configs = configsFromJson(root['configs']);
    final peers = _sharedPeers(root['peers'], legacy: root['v'] == 1);

    if (kind == ShareKind.network) {
      if (name == null) _reject('A network share has no name');
    } else {
      if (secret != null) _reject('A node share carries no secret');
      if (configs != null) _reject('A node share carries no configs');
      if ((root['peers'] as List).length != 1) {
        _reject('A node share has exactly one peer');
      }
    }
    return ShareDocument(
      kind: kind,
      name: name,
      secret: secret,
      configs: configs,
      peers: peers,
    );
  }
}

Never _reject(String message) => throw FormatException(message);

/// A trimmed, non-blank string field, or null when it is absent or blank.
String? _sharedText(Object? value, String field, int maxLength) {
  if (value == null) return null;
  if (value is! String) _reject('Share $field is not a string');
  final text = value.trim();
  if (text.length > maxLength) {
    _reject('Share $field is longer than $maxLength characters');
  }
  return text.isEmpty ? null : text;
}

List<SharedPeer> _sharedPeers(Object? value, {required bool legacy}) {
  if (value is! List<Object?>) _reject('Share document has no peer list');
  if (value.isEmpty || value.length > shareMaxPeers) {
    _reject('Share document has an invalid peer count');
  }
  return [
    for (final (index, entry) in value.indexed)
      ...legacy
          ? _legacyPeer(entry, 'Peer ${index + 1}')
          : [_sharedPeer(entry, 'Peer ${index + 1}')],
  ];
}

/// Whether [host] can be a shared peer's host.
///
/// A sender checks the address it is about to publish with this, and the
/// receiver rejects anything that fails it, so both sides agree on one rule.
bool shareableHost(String host) {
  if (host.trim().isEmpty) return false;
  if (host.length > _maxHostLength) return false;
  if (_invalidHostCharacters.hasMatch(host)) return false;
  // The address has to round-trip, or import would reach a different peer.
  try {
    return Uri(host: host).host == host;
  } on FormatException {
    return false;
  }
}

SharedPeer _sharedPeer(Object? entry, String field) {
  if (entry is! Map<String, Object?>) _reject('$field is not an object');
  final value = entry['url'];
  final url = value is String && value.length <= 4096
      ? Uri.tryParse(value)
      : null;
  if (url == null ||
      !isValidNodeUrl(value as String) ||
      !shareableHost(url.host) ||
      url.userInfo.isNotEmpty) {
    _reject('$field has an invalid connection URL');
  }
  return SharedPeer(
    url: url,
    publicKey: _sharedText(entry['publicKey'], 'publicKey', _maxKeyLength),
  );
}

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
