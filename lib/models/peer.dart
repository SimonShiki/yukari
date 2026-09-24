import 'node.dart';

enum SecureAuthLevel {
  none,
  encryptedUnauthenciated,
  peerVerified,
  networkSecretConfirmed,
}

enum IdentityType { admin, credential, sharedNode }

enum NatType {
  unknown,
  openInternet,
  noPat,
  fullCone,
  restricted,
  portRestricted,
  symmetric,
  symmetricUdpFirewall,
  symmetricEasyIncrement,
  symmetricEasyDecrement,
}

enum PeerConnectionType { local, direct, relay }

final class Peer {
  Peer({
    required this.id,
    required this.identityType,
    required this.hostname,
    required this.latency,
    required this.rxBytes,
    required this.txBytes,
    required this.rxPackets,
    required this.txPackets,
    required this.secureAuthLevel,
    required this.protocols,
    required this.natType,
    required this.connectionType,
  });

  final String id;
  final IdentityType identityType;
  final String hostname;
  final int latency;
  final int rxBytes;
  final int txBytes;
  final int rxPackets;
  final int txPackets;
  final SecureAuthLevel secureAuthLevel;
  final List<NodeProtocol> protocols;
  final NatType natType;
  final PeerConnectionType connectionType;

  factory Peer.fromJson(Map<String, Object?> json) {
    final route = json['route'] as Map<String, Object?>?;
    final peer = json['peer'] as Map<String, Object?>?;

    if (route == null || peer == null) {
      throw ArgumentError('Invalid JSON for Peer: $json');
    }

    final connections = (peer['conns'] as List<Object?>?)
        ?.cast<Map<String, Object?>>() ?? [];
    final connection = connections.firstOrNull ?? const <String, Object?>{};
    final stats = connection['stats'] as Map<String, Object?>?;
    final stunInfo = route['stun_info'] as Map<String, Object?>?;

    return Peer(
      id: '${route['peer_id']}',
      identityType:
          IdentityType.values[(connection['peer_identity_type'] as int?) ?? 0],
      hostname: route['hostname'] as String,
      latency: stats?['latency_us'] as int? ?? 0,
      rxBytes: stats?['rx_bytes'] as int? ?? 0,
      txBytes: stats?['tx_bytes'] as int? ?? 0,
      rxPackets: stats?['rx_packets'] as int? ?? 0,
      txPackets: stats?['tx_packets'] as int? ?? 0,
      secureAuthLevel: SecureAuthLevel
          .values[(connection['secure_auth_level'] as int?) ?? 0],
      protocols: [
        ...connections
            .map((connection) => connection['tunnel'] as Map<String, Object?>?)
            .whereType<Map<String, Object?>>()
            .map((tunnel) => tunnel['tunnel_type'] as String)
            .map(_protocolFromName)
            .whereType<NodeProtocol>(),
      ],
      natType: NatType.values[stunInfo?['udp_nat_type'] as int? ?? 0],
      connectionType: route['next_hop_peer_id'] == route['peer_id']
          ? PeerConnectionType.direct
          : PeerConnectionType.relay,
    );
  }

  static NodeProtocol? _protocolFromName(String name) {
    for (final protocol in NodeProtocol.values) {
      if (protocol.name == name) {
        return protocol;
      }
    }
    return null;
  }
}
