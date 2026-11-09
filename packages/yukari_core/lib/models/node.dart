import 'package:json_annotation/json_annotation.dart';

part 'node.g.dart';

/// Transport choices for listeners and EasyTier's default protocol.
enum NodeProtocol { tcp, udp, ws, wss, quic, wg }

/// Whether a connection URL has a scheme, a host and a usable port.
/// Paths and queries belong to the connection; fragments do not.
bool isValidNodeUrl(String value) {
  final url = Uri.tryParse(value);
  if (url == null ||
      RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://[^/?#]*:0+(?=[/?#]|$)')
          .hasMatch(value)) {
    return false;
  }
  try {
    return url.hasScheme &&
        url.hasAuthority &&
        url.host.isNotEmpty &&
        !url.hasFragment &&
        !RegExp(r'\s').hasMatch(value) &&
        ((url.hasPort && url.port > 0 && url.port <= 65535) ||
            (!url.hasPort &&
                {'http', 'https', 'ws', 'wss'}.contains(url.scheme)));
  } on FormatException {
    return false;
  }
}

/// A connection's complete address. Names and public key pins are metadata.
Uri nodeIdentity(Node node) => node.url;

bool sameNode(Node a, Node b) => nodeIdentity(a) == nodeIdentity(b);

/// Copies a bookmarked connection into a network without reusing a row name.
Node copyNodeForNetwork(Node node, Iterable<Node> existing) {
  final copy = node.copy();
  var suffix = 2;
  while (existing.any((peer) => peer.name == copy.name)) {
    copy.name = '${node.name} (${suffix++})';
  }
  return copy;
}

@JsonSerializable()
final class Node {
  Node({required this.name, required this.url, this.publicKey});

  String name;
  Uri url;
  String? publicKey;

  factory Node.fromJson(Map<String, dynamic> json) => _$NodeFromJson(json);

  Map<String, dynamic> toJson() => _$NodeToJson(this);

  Node copy() => Node.fromJson(toJson());
}

/// Reads an old host/port/protocols entry without losing any of its endpoints.
/// New documents always store one full connection URL per node.
List<Node> nodesFromJson(Map<String, dynamic> json) {
  if (!json.containsKey('protocols')) return [Node.fromJson(json)];
  final protocols = (json['protocols'] as List).cast<String>().toSet();
  final port = (json['port'] as num).toInt();
  if (protocols.isEmpty || port < 1 || port > 65535) {
    throw const FormatException('Invalid legacy node connection');
  }
  final url = Uri.parse(json['url'] as String);
  final name = json['id'] as String;
  final host = url.host.isEmpty ? url.path : url.host;
  return [
    for (final (index, protocol) in protocols.indexed)
      Node(
        name: index == 0 ? name : '$name ($protocol)',
        url: Uri(
          scheme: NodeProtocol.values.byName(protocol).name,
          userInfo: url.userInfo,
          host: host,
          port: port,
          path: url.host.isEmpty ? '' : url.path,
          query: url.hasQuery ? url.query : null,
        ),
        publicKey: json['publicKey'] as String?,
      ),
  ];
}
