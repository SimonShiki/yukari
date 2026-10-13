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
    this.virtualIpv4,
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

  /// Address in the virtual network, such as `10.144.0.1`, once assigned.
  final String? virtualIpv4;

  factory Peer.fromJson(Map<String, Object?> json) {
    final route = json['route'] as Map<String, Object?>?;
    final peer = json['peer'] as Map<String, Object?>?;

    if (route == null || peer == null) {
      throw ArgumentError('Invalid JSON for Peer: $json');
    }

    final connections =
        (peer['conns'] as List<Object?>?)?.cast<Map<String, Object?>>() ?? [];
    final connection = connections.firstOrNull ?? const <String, Object?>{};
    final stats = connection['stats'] as Map<String, Object?>?;

    return Peer(
      id: '${route['peer_id']}',
      identityType: _enum(
        IdentityType.values,
        _identityTypeNames,
        connection['peer_identity_type'],
      ),
      hostname: route['hostname'] as String? ?? '',
      latency: _int(stats?['latency_us']),
      rxBytes: _int(stats?['rx_bytes']),
      txBytes: _int(stats?['tx_bytes']),
      rxPackets: _int(stats?['rx_packets']),
      txPackets: _int(stats?['tx_packets']),
      secureAuthLevel: _enum(
        SecureAuthLevel.values,
        _secureAuthLevelNames,
        connection['secure_auth_level'],
      ),
      protocols: [
        ...connections
            .map((connection) => connection['tunnel'] as Map<String, Object?>?)
            .whereType<Map<String, Object?>>()
            .map((tunnel) => tunnel['tunnel_type'] as String? ?? '')
            .map(_protocolFromName)
            .whereType<NodeProtocol>(),
      ],
      natType: natTypeOf(route['stun_info']),
      connectionType: route['next_hop_peer_id'] == route['peer_id']
          ? PeerConnectionType.direct
          : PeerConnectionType.relay,
      virtualIpv4: ipv4FromInet(route['ipv4_addr']),
    );
  }

  /// The UDP NAT type a `StunInfo` message reports.
  static NatType natTypeOf(Object? stunInfo) => _enum(
    NatType.values,
    _natTypeNames,
    (stunInfo as Map<String, Object?>?)?['udp_nat_type'],
  );

  /// Formats an `Ipv4Inet` message, whose address is a big-endian integer.
  static String? ipv4FromInet(Object? inet) {
    if (inet case {'address': {'addr': final int addr}}) {
      return [24, 16, 8, 0].map((shift) => (addr >> shift) & 0xff).join('.');
    }
    return null;
  }

  // EasyTier serializes protobuf messages with serde: 64-bit integers become
  // strings, enums become variant names, and default values are omitted.
  static const _identityTypeNames = ['Admin', 'Credential', 'SharedNode'];
  static const _secureAuthLevelNames = [
    'None',
    'EncryptedUnauthenticated',
    'PeerVerified',
    'NetworkSecretConfirmed',
  ];
  static const _natTypeNames = [
    'Unknown',
    'OpenInternet',
    'NoPAT',
    'FullCone',
    'Restricted',
    'PortRestricted',
    'Symmetric',
    'SymUdpFirewall',
    'SymmetricEasyInc',
    'SymmetricEasyDec',
  ];

  static int _int(Object? value) => switch (value) {
    int value => value,
    String value => int.tryParse(value) ?? 0,
    _ => 0,
  };

  /// [values] must follow the order of the protobuf enum's [names].
  static T _enum<T>(List<T> values, List<String> names, Object? value) {
    final index = switch (value) {
      int value => value,
      String value => names.indexOf(value),
      _ => 0,
    };
    return index >= 0 && index < values.length ? values[index] : values.first;
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
