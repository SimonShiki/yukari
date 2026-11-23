import 'dart:io';
import 'dart:typed_data';

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
    this.virtualIpv6,
    this.fecActive = false,
    this.fecRecovered = 0,
  });

  final String id;
  final IdentityType identityType;
  final String hostname;
  final int? latency;
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

  /// IPv6 address in the virtual network, such as `fd6b:8c2d:91e4::1`, once assigned.
  final String? virtualIpv6;

  /// Whether UDP FEC is active on any connection to this peer.
  final bool fecActive;

  /// Total packets recovered by UDP FEC across connections to this peer.
  final int fecRecovered;

  factory Peer.fromJson(Map<String, Object?> json) {
    final route = json['route'] as Map<String, Object?>?;
    if (route == null) {
      throw ArgumentError('Invalid JSON for Peer: $json');
    }

    final peer = json['peer'] as Map<String, Object?>?;
    final connections =
        (peer?['conns'] as List<Object?>?)?.cast<Map<String, Object?>>() ??
        const [];
    final connection = connections.firstOrNull ?? const <String, Object?>{};
    final stats = connection['stats'] as Map<String, Object?>?;
    var fecActive = false;
    var fecRecovered = 0;
    final protocols = <NodeProtocol>{};
    for (final conn in connections) {
      if (conn['fec'] case final Map<String, Object?> fec) {
        if (fec['active'] == true) fecActive = true;
        fecRecovered += _int(fec['recovered']);
      }
      if (conn['tunnel'] case {'tunnel_type': final String type}) {
        if (_protocolFromName(type) case final protocol?) {
          protocols.add(protocol);
        }
      }
    }

    return Peer(
      id: '${route['peer_id']}',
      hostname: route['hostname'] as String? ?? '',
      natType: natTypeOf(route['stun_info']),
      connectionType: route['next_hop_peer_id'] == route['peer_id']
          ? PeerConnectionType.direct
          : PeerConnectionType.relay,
      virtualIpv4: ipv4FromInet(route['ipv4_addr']),
      virtualIpv6: ipv6FromInet(route['ipv6_addr']),
      fecActive: fecActive,
      fecRecovered: fecRecovered,
      identityType: _enum(
        IdentityType.values,
        _identityTypeNames,
        connection['peer_identity_type'],
      ),
      latency: switch (stats?['latency_us']) {
        null => null,
        final value => _int(value),
      },
      rxBytes: _int(stats?['rx_bytes']),
      txBytes: _int(stats?['tx_bytes']),
      rxPackets: _int(stats?['rx_packets']),
      txPackets: _int(stats?['tx_packets']),
      secureAuthLevel: _enum(
        SecureAuthLevel.values,
        _secureAuthLevelNames,
        connection['secure_auth_level'],
      ),
      protocols: protocols.toList(growable: false),
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
    if (inet is String && inet.isNotEmpty) {
      return _validatedCidr(inet, 32, includePrefix: false);
    }
    if (inet case {'address': {'addr': final int addr}}) {
      return _ipv4Host(addr);
    }
    return null;
  }

  /// Formats an `Ipv4Inet` protobuf message, including its network prefix.
  static String? ipv4CidrFromInet(Object? inet) {
    if (inet is String && inet.isNotEmpty) return _validatedCidr(inet, 32);
    if (inet case {'address': {'addr': final int addr}}) {
      final host = _ipv4Host(addr);
      if (inet case {'network_length': final int length}) {
        return length >= 0 && length <= 32 ? '$host/$length' : null;
      }
      return host;
    }
    return null;
  }

  static String _ipv4Host(int addr) =>
      '${(addr >> 24) & 0xff}.${(addr >> 16) & 0xff}.'
      '${(addr >> 8) & 0xff}.${addr & 0xff}';

  /// Formats an `Ipv6Inet` message, whose address consists of four 32-bit parts.
  static String? ipv6FromInet(Object? inet) {
    if (inet is String && inet.isNotEmpty) {
      return _validatedCidr(inet, 128, includePrefix: false);
    }
    if (inet case {
      'address': {
        'part1': final int p1,
        'part2': final int p2,
        'part3': final int p3,
        'part4': final int p4,
      },
    }) {
      return _ipv6Host(p1, p2, p3, p4);
    }
    return null;
  }

  /// Formats an `Ipv6Inet` protobuf message, including its network prefix.
  static String? ipv6CidrFromInet(Object? inet) {
    if (inet is String && inet.isNotEmpty) {
      return _validatedCidr(inet, 128);
    }
    if (inet case {
      'address': {
        'part1': final int p1,
        'part2': final int p2,
        'part3': final int p3,
        'part4': final int p4,
      },
    }) {
      final host = _ipv6Host(p1, p2, p3, p4);
      if (inet case {'network_length': final int length}) {
        return length >= 0 && length <= 128 ? '$host/$length' : null;
      }
      return host;
    }
    return null;
  }

  static String _ipv6Host(int p1, int p2, int p3, int p4) {
    final bytes = Uint8List(16);
    ByteData.sublistView(bytes)
      ..setUint32(0, p1)
      ..setUint32(4, p2)
      ..setUint32(8, p3)
      ..setUint32(12, p4);
    return InternetAddress.fromRawAddress(bytes).address;
  }

  static String? _validatedCidr(
    String value,
    int maxPrefix, {
    bool includePrefix = true,
  }) {
    final parts = value.trim().split('/');
    if (parts.length > 2) return null;
    final address = InternetAddress.tryParse(parts.first);
    if (address == null ||
        (maxPrefix == 32) != (address.type == InternetAddressType.IPv4)) {
      return null;
    }
    if (parts.length == 1) return address.address;
    final prefix = int.tryParse(parts.last);
    if (prefix == null || prefix < 0 || prefix > maxPrefix) return null;
    return includePrefix ? '${address.address}/$prefix' : address.address;
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
