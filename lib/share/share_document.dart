import 'dart:convert';

import 'package:yukari_core/models/node.dart';

/// The share format version [ShareDocument.encode] writes; a document from a
/// newer version is refused rather than guessed at.
const int shareDocumentVersion = 1;

/// The media type a share document carries when it leaves the app.
const String shareContentType = 'application/vnd.yukari.share+json';

/// The largest document content [ShareDocument.decode] accepts, in bytes.
const int shareMaxBytes = 64 * 1024;

/// The most peers a share document may carry.
const int shareMaxPeers = 64;

const int _maxNameLength = 128;
const int _maxHostLength = 253;
const int _maxPathLength = 256;
const int _maxKeyLength = 512; // The longest secret or public key.

final RegExp _invalidHostCharacters = RegExp(r'[\s/@?#%]');
final RegExp _invalidPathCharacters = RegExp(r'[?#\s]');

/// Whether a shared document describes a whole network or a single node.
enum ShareKind { network, node }

/// One peer of a shared network, or the single peer of a shared node.
final class SharedPeer {
  const SharedPeer({
    required this.host,
    required this.port,
    required this.protocols,
    this.publicKey,
    this.path,
  });

  /// The peer's host, without brackets even for an IPv6 literal.
  final String host;
  final int port;

  /// The protocols the peer offers, deduplicated and in the sender's order.
  final List<NodeProtocol> protocols;

  /// The peer's public key, shared so the receiver can pin the peer.
  final String? publicKey;

  /// The peer's authority-relative path, such as `/ws`.
  final String? path;

  String get address => '$host:$port';

  Map<String, Object?> toJson() => {
    'host': host,
    'port': port,
    'protocols': [for (final protocol in protocols) protocol.name],
    if (publicKey != null) 'publicKey': publicKey,
    if (path != null) 'path': path,
  };
}

/// The shareable subset of a saved network or node.
///
/// A document carries only what the receiver needs: a network's name, its
/// secret and its peers, or a single node. [encode] writes the compact,
/// versioned JSON a QR payload or the clipboard carries; a channel may
/// compress it, and [decode] reads the JSON back.
final class ShareDocument {
  const ShareDocument({
    required this.kind,
    required this.peers,
    this.name,
    this.secret,
  });

  final ShareKind kind;

  /// The network's name; absent from a node share.
  final String? name;

  /// The network's secret; absent from a node share, or when it has none.
  final String? secret;

  final List<SharedPeer> peers;

  bool get hasSecret => secret != null;

  /// This document as the compact JSON a share channel carries.
  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() => {
    'v': shareDocumentVersion,
    'kind': kind.name,
    if (name != null) 'name': name,
    if (secret != null) 'secret': secret,
    'peers': [for (final peer in peers) peer.toJson()],
  };

  /// Parses untrusted [content], rejecting anything malformed.
  static ShareDocument decode(String content) =>
      decodeRoot(parseRoot(content));

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
    if (version != shareDocumentVersion) {
      _reject('Unsupported share format version: $version');
    }
    final kind = switch (root['kind']) {
      'network' => ShareKind.network,
      'node' => ShareKind.node,
      final Object? other => _reject('Unknown share kind: $other'),
    };
    final name = _sharedText(root['name'], 'name', _maxNameLength);
    final secret = _sharedText(root['secret'], 'secret', _maxKeyLength);
    final peers = _sharedPeers(root['peers']);

    if (kind == ShareKind.network) {
      if (name == null) _reject('A network share has no name');
    } else {
      if (name != null || secret != null) {
        _reject('A node share carries no name or secret');
      }
      if (peers.length != 1) _reject('A node share has exactly one peer');
    }
    return ShareDocument(kind: kind, name: name, secret: secret, peers: peers);
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

List<SharedPeer> _sharedPeers(Object? value) {
  if (value is! List<Object?>) _reject('Share document has no peer list');
  if (value.isEmpty || value.length > shareMaxPeers) {
    _reject('Share document has an invalid peer count');
  }
  return [
    for (final (index, entry) in value.indexed)
      _sharedPeer(entry, 'Peer ${index + 1}'),
  ];
}

SharedPeer _sharedPeer(Object? entry, String field) {
  if (entry is! Map<String, Object?>) _reject('$field is not an object');

  final host = entry['host'];
  if (host is! String || host.trim().isEmpty) _reject('$field has no host');
  if (host.length > _maxHostLength) _reject('$field host is too long');
  if (_invalidHostCharacters.hasMatch(host)) {
    _reject('$field has an invalid host');
  }
  final path = _sharedPath(entry['path'], field);
  // The address has to round-trip, or import would reach a different peer.
  try {
    if (nodeHost(nodeUrlForHost(host)) != host) {
      _reject('$field has an invalid host');
    }
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

  return SharedPeer(
    host: host,
    port: port,
    protocols: protocols,
    publicKey: _sharedText(entry['publicKey'], 'publicKey', _maxKeyLength),
    path: path,
  );
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
