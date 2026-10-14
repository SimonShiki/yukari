import 'package:json_annotation/json_annotation.dart';

part 'node.g.dart';

/// The host of a peer address, which has no scheme when written bare, such
/// as `example.com`.
String nodeHost(Uri uri) => uri.host.isNotEmpty ? uri.host : uri.path;

/// Whether [host] is an IPv6 literal, which only parses back inside brackets.
bool _isIpv6Literal(String host) => host.contains(':');

/// The URL stored for a peer [host] typed without a scheme, as a config's
/// `tcp://host:11010` peer reduces to.
///
/// A bare host parses as a path; an IPv6 literal cannot, so it keeps the
/// bracketed authority-only form `//[::1]`.
Uri nodeUrlForHost(String host) =>
    _isIpv6Literal(host) ? Uri(host: host) : Uri.parse(host);

/// The peer address as an editor shows it, and as [nodeUrlForHost] stores it:
/// without the `//` an authority-only URI would otherwise print.
///
/// Addresses with a scheme, a path or an IPv6 host keep their full form,
/// which is what `Uri.parse` reads back unchanged.
String nodeUrlText(Uri uri) {
  if (uri.host.isEmpty) return uri.path;
  if (uri.scheme.isEmpty && uri.path.isEmpty && !_isIpv6Literal(uri.host)) {
    return uri.host;
  }
  return uri.toString();
}

/// Whether both nodes reach the same host and port, whatever they are named
/// or which protocols they offer.
bool sameNode(Node a, Node b) =>
    nodeHost(a.url) == nodeHost(b.url) && a.port == b.port;

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

  /// A deep, independent copy of this node.
  Node copy() => Node.fromJson(toJson());

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
