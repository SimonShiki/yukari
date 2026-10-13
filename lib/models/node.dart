import 'package:json_annotation/json_annotation.dart';

part 'node.g.dart';

/// The host of a peer address, which has no scheme when written bare, such
/// as `example.com`.
String nodeHost(Uri uri) => uri.host.isNotEmpty ? uri.host : uri.path;

enum NodeProtocol { tcp, udp, ws, wss, quic, wg }

@JsonSerializable()
final class Node {
  Node({
    required this.id,
    required this.url,
    required this.port,
    required this.protocols,
    this.publicKey,
  });

  String id;
  Uri url;
  int port;
  List<NodeProtocol> protocols;
  String? publicKey;

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
