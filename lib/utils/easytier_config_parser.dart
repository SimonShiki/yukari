import 'dart:collection';

import 'package:toml/toml.dart';

import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/utils/dns_name.dart';

/// Converts EasyTier TOML [tomlContent] into an editable [Network].
Network parseEasyTierConfig(String tomlContent) {
  final doc = TomlDocument.parse(tomlContent);
  final config = _TrackingMap(doc.toMap());

  final network = Network();

  if (config['hostname'] is String) {
    network.hostname = config['hostname'] as String;
  }

  if (config['network_identity'] is Map) {
    final identity = config['network_identity'] as Map;
    if (identity['network_name'] is String) {
      network.networkName = identity['network_name'] as String;
    }
    if (identity['network_secret'] is String) {
      network.networkSecret = identity['network_secret'] as String;
    }
  }

  if (config['netns'] is String) {
    network.netNamespace = config['netns'] as String;
  }

  if (config['ipv4'] is String) {
    network.ipv4 = config['ipv4'] as String;
  }

  if (config['ipv6'] is String) {
    network.ipv6 = config['ipv6'] as String;
  }

  if (config['ipv6_public_addr_provider'] is bool) {
    network.ipv6PublicAddressProvider =
        config['ipv6_public_addr_provider'] as bool;
  }

  if (config['ipv6_public_addr_auto'] is bool) {
    network.ipv6PublicAddressAuto = config['ipv6_public_addr_auto'] as bool;
  }

  if (config['ipv6_public_addr_prefix'] is String) {
    network.ipv6PublicAddressPrefix =
        config['ipv6_public_addr_prefix'] as String;
  }

  final dhcp = config['dhcp'];
  if (dhcp is bool) {
    network.dhcp = dhcp;
  } else if (dhcp is String) {
    if (dhcp.trim().isEmpty) {
      throw const FormatException('dhcp CIDR cannot be empty');
    }
    network.dhcp = true;
    network.dhcpIpv4Cidr = dhcp;
  }

  final dhcpv6 = config['dhcpv6'];
  if (dhcpv6 is bool) {
    network.dhcpv6 = dhcpv6;
  } else if (dhcpv6 is String) {
    if (dhcpv6.trim().isEmpty) {
      throw const FormatException('dhcpv6 CIDR cannot be empty');
    }
    network.dhcpv6 = true;
    network.dhcpIpv6Cidr = dhcpv6;
  }

  final rawDns = config['dns'];
  if (rawDns != null) {
    if (rawDns is! Map) throw const FormatException('dns must be a table');
    network.dns = _parseDns(rawDns);
  }

  if (config['listeners'] is List) {
    network.listeners = (config['listeners'] as List)
        .map((e) => Uri.parse(e.toString()))
        .toList();
  }

  if (config['mapped_listeners'] is List) {
    network.mappedListeners = (config['mapped_listeners'] as List)
        .map((e) => Uri.parse(e.toString()))
        .toList();
  }

  if (config['exit_nodes'] is List) {
    network.exitNodes = (config['exit_nodes'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['peer'] is List) {
    network.nodes = _parsePeers(config['peer'] as List);
  }

  if (config['proxy_network'] is List) {
    network.proxyNetworks = (config['proxy_network'] as List)
        .map((e) => _parseProxyNetwork(e as Map))
        .toList();
  }

  if (config['routes'] is List) {
    network.routes = (config['routes'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['socks5_proxy'] is String) {
    network.socks5Proxy = Uri.parse(config['socks5_proxy'] as String);
  }

  if (config['port_forward'] is List) {
    network.portForwards = (config['port_forward'] as List)
        .map((e) => _parsePortForward(e as Map))
        .toList();
  }

  if (config['vpn_portal_config'] is Map) {
    network.vpnPortal = _parseVpnPortal(config['vpn_portal_config'] as Map);
  }

  if (config['secure_mode'] is Map) {
    network.secureMode = _parseSecureMode(config['secure_mode'] as Map);
  }

  if (config['acl'] is Map) {
    network.acl = Map<String, Object?>.from(config['acl'] as Map);
  }

  if (config['tcp_whitelist'] is List) {
    network.tcpWhitelist = (config['tcp_whitelist'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['udp_whitelist'] is List) {
    network.udpWhitelist = (config['udp_whitelist'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['stun_servers'] is List) {
    network.stunServers = (config['stun_servers'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['tcp_stun_servers'] is List) {
    network.tcpStunServers = (config['tcp_stun_servers'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['stun_servers_v6'] is List) {
    network.stunServersV6 = (config['stun_servers_v6'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['credential_file'] is String) {
    network.credentialFile = config['credential_file'] as String;
  }

  if (config['managed_credentials'] is List) {
    network.managedCredentials = (config['managed_credentials'] as List)
        .map((e) => _parseManagedCredential(e as Map))
        .toList();
  }

  if (config['flags'] is Map) {
    final flags = _TrackingMap(config['flags'] as Map);
    network.flags = _parseFlags(flags);
    network.additionalFlags = flags.unread;
  }

  if (network.dns?.domain case final String domain when domain.isNotEmpty) {
    network.flags.dnsZone = domain;
  }

  network.additionalConfiguration = config.unread;

  return network;
}

/// Tracks which fields the typed parser consumed, so the unread ones become
/// extensions without a second copy of the schema.
final class _TrackingMap extends MapBase<dynamic, dynamic> {
  _TrackingMap(Map<dynamic, dynamic> source) : _source = source;

  final Map<dynamic, dynamic> _source;
  final _read = <Object?>{};

  Map<String, Object?> get unread => {
    for (final MapEntry(:key, :value) in _source.entries)
      if (!_read.contains(key)) key as String: value as Object?,
  };

  @override
  Iterable<dynamic> get keys => _source.keys;

  @override
  dynamic operator [](Object? key) {
    _read.add(key);
    return _source[key];
  }

  @override
  void operator []=(dynamic key, dynamic value) => _source[key] = value;

  @override
  void clear() => _source.clear();

  @override
  dynamic remove(Object? key) => _source.remove(key);
}

List<Node> _parsePeers(List<dynamic> peers) => [
  for (final peer in peers)
    if (peer case {'uri': final String uri})
      if (Uri.tryParse(uri) case final Uri url when isValidNodeUrl(uri, url))
        Node(
          name: uri,
          url: url,
          publicKey: peer['peer_public_key']?.toString(),
        ),
];

NodeProtocol? _parseNodeProtocol(String scheme) =>
    switch (scheme.toLowerCase()) {
      'tcp' => NodeProtocol.tcp,
      'udp' => NodeProtocol.udp,
      'ws' => NodeProtocol.ws,
      'wss' => NodeProtocol.wss,
      'quic' => NodeProtocol.quic,
      'wg' => NodeProtocol.wg,
      _ => null,
    };

ProxyNetwork _parseProxyNetwork(Map<dynamic, dynamic> data) => ProxyNetwork(
  cidr: data['cidr'].toString(),
  mappedCidr: data['mapped_cidr']?.toString(),
  allow: data['allow'] is List
      ? (data['allow'] as List).map((e) => e.toString()).toList()
      : [],
);

PortForward _parsePortForward(Map<dynamic, dynamic> data) => PortForward(
  protocol: data['proto'].toString(),
  bindAddress: data['bind_addr'].toString(),
  destinationAddress: data['dst_addr'].toString(),
);

VpnPortal _parseVpnPortal(Map<dynamic, dynamic> data) => VpnPortal(
  enabled: data['enabled'] as bool? ?? true,
  wireguardListen: data['wireguard_listen'].toString(),
  wireguardPrivateKey: data['wireguard_private_key']?.toString(),
  clients: data['clients'] is List
      ? (data['clients'] as List)
            .map((e) => _parseVpnPortalClient(e as Map<dynamic, dynamic>))
            .toList()
      : [],
);

VpnPortalClient _parseVpnPortalClient(Map<dynamic, dynamic> data) =>
    VpnPortalClient(
      name: data['name'].toString(),
      virtualIp: data['virtual_ip'].toString(),
      groups: data['groups'] is List
          ? (data['groups'] as List).map((e) => e.toString()).toList()
          : [],
    );

SecureMode _parseSecureMode(Map<dynamic, dynamic> data) => SecureMode(
  enabled: data['enabled'] as bool? ?? true,
  localPrivateKey: data['local_private_key']?.toString(),
  localPublicKey: data['local_public_key']?.toString(),
);

ManagedCredential _parseManagedCredential(Map<dynamic, dynamic> data) =>
    ManagedCredential(
      id: data['credential_id'].toString(),
      secret: data['credential_secret'].toString(),
      expiryUnix: data['expiry_unix'] as int,
      groups: data['groups'] is List
          ? (data['groups'] as List).map((e) => e.toString()).toList()
          : [],
      allowRelay: data['allow_relay'] as bool? ?? false,
      allowedProxyCidrs: data['allowed_proxy_cidrs'] is List
          ? (data['allowed_proxy_cidrs'] as List)
                .map((e) => e.toString())
                .toList()
          : [],
      reusable: data['reusable'] as bool? ?? true,
    );

DnsConfig _parseDns(Map<dynamic, dynamic> source) {
  final data = _TrackingMap(source);
  final rawDomain = data['domain'];
  if (rawDomain != null && rawDomain is! String) {
    throw const FormatException('dns.domain must be a string');
  }
  final domain = rawDomain is String && rawDomain.trim().isNotEmpty
      ? rawDomain.trim()
      : null;
  final rawZones = data['zone'];
  final zones = <DnsZone>[];
  if (rawZones != null && rawZones is! List) {
    throw const FormatException('dns.zone must be an array of tables');
  }
  if (rawZones is List) {
    for (final entry in rawZones) {
      if (entry is! Map) {
        throw const FormatException('DNS zone entry must be a map');
      }
      final zone = _TrackingMap(entry);
      final origin = zone['origin']?.toString().trim() ?? '';
      if (origin.isEmpty) {
        throw const FormatException('DNS zone origin cannot be empty');
      }
      final ttl = _parseDnsTtl(zone['ttl']);
      final records = <DnsRecord>[];
      final rawRecords = zone['records'];
      if (rawRecords != null && rawRecords is! List) {
        throw const FormatException('DNS records must be an array');
      }
      if (rawRecords is List) {
        for (final rawRecord in rawRecords) {
          if (rawRecord is! Map) {
            throw const FormatException('DNS record entry must be a map');
          }
          final record = _TrackingMap(rawRecord);
          final name = record['name']?.toString().trim() ?? '';
          final value = record['value']?.toString() ?? '';
          final typeText = record['type']?.toString() ?? '';
          final type = DnsRecordType.tryParse(typeText);
          if (name.isEmpty || value.trim().isEmpty || type == null) {
            throw FormatException('Invalid DNS record: $rawRecord');
          }
          records.add(
            DnsRecord(
              name: name,
              type: type,
              value: value,
              ttl: _parseDnsTtl(record['ttl']),
            ),
          );
          if (record.unread.isNotEmpty) {
            throw FormatException(
              'Unknown DNS record keys: ${record.unread.keys.join(', ')}',
            );
          }
        }
      }
      if (zone.unread.isNotEmpty) {
        throw FormatException(
          'Unknown DNS zone keys: ${zone.unread.keys.join(', ')}',
        );
      }
      zones.add(DnsZone(origin: origin, ttl: ttl, records: records));
    }
  }
  if (data.unread.isNotEmpty) {
    throw FormatException('Unknown DNS keys: ${data.unread.keys.join(', ')}');
  }
  return DnsConfig(domain: domain, zones: zones);
}

int? _parseDnsTtl(Object? value) {
  if (value == null) return null;
  if (value is! int || value < 0 || value > 2147483647) {
    throw const FormatException(
      'DNS TTL must be an integer from 0 to 2147483647',
    );
  }
  return value;
}

NetworkFlags _parseFlags(_TrackingMap data) {
  CompressionAlgorithm parseCompressionAlgorithm(String value) =>
      switch (value.toLowerCase()) {
        'zstd' => CompressionAlgorithm.zstd,
        'lzo' => CompressionAlgorithm.lzo,
        _ => CompressionAlgorithm.none,
      };

  EncryptionAlgorithm parseEncryptionAlgorithm(Object? value) {
    if (value == null) return NetworkFlags().encryptionAlgorithm;
    if (value is! String) {
      throw const FormatException('encryption_algorithm must be a string');
    }
    return switch (value.toLowerCase()) {
      'aes-gcm' || 'openssl-aes-gcm' => EncryptionAlgorithm.aesGcm,
      'aes-256-gcm' || 'openssl-aes-256-gcm' => EncryptionAlgorithm.aes256Gcm,
      'chacha20' ||
      'chacha20-poly1305' ||
      'openssl-chacha20' => EncryptionAlgorithm.chacha20,
      'xor' => EncryptionAlgorithm.xor,
      _ => throw FormatException('Unsupported encryption_algorithm', value),
    };
  }

  return NetworkFlags(
    defaultProtocol: data['default_protocol'] is String
        ? _parseNodeProtocol(data['default_protocol'] as String) ??
              NodeProtocol.tcp
        : NodeProtocol.tcp,
    deviceName: data['dev_name']?.toString() ?? '',
    enableEncryption: data['enable_encryption'] as bool? ?? true,
    enableIpv6: data['enable_ipv6'] as bool? ?? true,
    mtu: data['mtu'] as int? ?? 1380,
    latencyFirst: data['latency_first'] as bool? ?? false,
    enableExitNode: data['enable_exit_node'] as bool? ?? false,
    proxyForwardBySystem: data['proxy_forward_by_system'] as bool? ?? false,
    noTun: data['no_tun'] as bool? ?? false,
    useSmoltcp: data['use_smoltcp'] as bool? ?? false,
    relayNetworkWhitelist: data['relay_network_whitelist']?.toString() ?? '*',
    disableP2p: data['disable_p2p'] as bool? ?? false,
    p2pOnly: data['p2p_only'] as bool? ?? false,
    lazyP2p: data['lazy_p2p'] as bool? ?? false,
    relayAllPeerRpc: data['relay_all_peer_rpc'] as bool? ?? false,
    disableTcpHolePunching: data['disable_tcp_hole_punching'] as bool? ?? false,
    disableUdpHolePunching: data['disable_udp_hole_punching'] as bool? ?? false,
    multiThread: data['multi_thread'] as bool? ?? true,
    compressionAlgorithm: data['data_compress_algo'] is String
        ? parseCompressionAlgorithm(data['data_compress_algo'] as String)
        : CompressionAlgorithm.none,
    bindDevice: data['bind_device'] as bool? ?? true,
    enableKcpProxy: data['enable_kcp_proxy'] as bool? ?? false,
    disableKcpInput: data['disable_kcp_input'] as bool? ?? false,
    disableRelayKcp: data['disable_relay_kcp'] as bool? ?? false,
    enableRelayForeignNetworkKcp:
        data['enable_relay_foreign_network_kcp'] as bool? ?? false,
    acceptDns: data['accept_dns'] as bool? ?? false,
    privateMode: data['private_mode'] as bool? ?? false,
    enableQuicProxy: data['enable_quic_proxy'] as bool? ?? false,
    disableQuicInput: data['disable_quic_input'] as bool? ?? false,
    disableRelayQuic: data['disable_relay_quic'] as bool? ?? false,
    enableRelayForeignNetworkQuic:
        data['enable_relay_foreign_network_quic'] as bool? ?? false,
    foreignRelayBpsLimit: data['foreign_relay_bps_limit'] is String
        ? int.tryParse(data['foreign_relay_bps_limit'] as String)
        : data['foreign_relay_bps_limit'] as int?,
    multiThreadCount: data['multi_thread_count'] as int? ?? 2,
    encryptionAlgorithm: parseEncryptionAlgorithm(data['encryption_algorithm']),
    disableSymmetricHolePunching:
        data['disable_sym_hole_punching'] as bool? ?? false,
    dnsZone: data['tld_dns_zone']?.toString() ?? defaultDnsDomain,
    quicListenPort: data['quic_listen_port'] as int?,
    needP2p: data['need_p2p'] as bool? ?? false,
    instanceReceiveBpsLimit: data['instance_recv_bps_limit'] is String
        ? int.tryParse(data['instance_recv_bps_limit'] as String)
        : data['instance_recv_bps_limit'] as int?,
    disableUpnp: data['disable_upnp'] as bool? ?? false,
    disableRelayData: data['disable_relay_data'] as bool? ?? false,
    preferPeerRelay: data['prefer_peer_relay'] as bool? ?? false,
    enableUdpBroadcastRelay:
        data['enable_udp_broadcast_relay'] as bool? ?? false,
    socketMark: data['socket_mark'] as int?,
    enableUdpFec: data['enable_udp_fec'] as bool? ?? false,
    enableUdpFecKcp: data['enable_udp_fec_kcp'] as bool? ?? false,
    enableUdpFecQuic: data['enable_udp_fec_quic'] as bool? ?? false,
  );
}
