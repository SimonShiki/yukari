import 'package:json_annotation/json_annotation.dart';

import '../utils/validator.dart';

part 'node.g.dart';

enum NodeProtocol { tcp, udp, ws, wss, quic, wg }

@JsonSerializable()
final class Node {
  Node({
    required this.id,
    required this.url,
    required this.port,
    required Iterable<NodeProtocol> protocols,
    this.publicKey,
  }) : protocols = List.unmodifiable(protocols) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Cannot be empty');
    }
    if (url.hasQuery || url.hasFragment || nodeHost(url).isEmpty) {
      throw ArgumentError.value(
        url,
        'url',
        'Must contain a valid address and cannot contain a query or fragment',
      );
    }
    if (port < 1 || port > 65535) {
      throw RangeError.range(port, 1, 65535, 'port');
    }
    if (this.protocols.isEmpty) {
      throw ArgumentError.value(protocols, 'protocols', 'Cannot be empty');
    }
    if (this.protocols.toSet().length != this.protocols.length) {
      throw ArgumentError.value(
        protocols,
        'protocols',
        'Cannot contain duplicate protocols',
      );
    }
    if (publicKey != null && publicKey!.trim().isEmpty) {
      throw ArgumentError.value(
        publicKey,
        'publicKey',
        'Cannot be an empty string',
      );
    }
  }

  final String id;
  final Uri url;
  final int port;
  final List<NodeProtocol> protocols;
  final String? publicKey;

  factory Node.fromJson(Map<String, dynamic> json) => _$NodeFromJson(json);

  Map<String, dynamic> toJson() => _$NodeToJson(this);

  Uri endpoint(NodeProtocol protocol) {
    final host = nodeHost(url);
    return Uri(
      scheme: protocol.name,
      userInfo: url.userInfo,
      host: host,
      port: port,
      path: url.host.isEmpty ? '' : url.path,
    );
  }
}
