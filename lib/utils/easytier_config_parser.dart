import 'dart:collection';

import 'package:toml/toml.dart';

import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/utils/dns_name.dart';

/// Converts EasyTier TOML [tomlContent] into an editable [Network].
Network parseEasyTierConfig(String tomlContent) {
  final doc = TomlDocument.parse(tomlContent);
  final config = _TrackingMap(doc.toMap());

  final network = Network();

  if (config['hostname'] case final String hostname) {
    network.hostname = hostname;
  }

  if (config['network_identity'] case final Map<dynamic, dynamic> identity) {
    if (identity['network_name'] case final String name) {
      network.networkName = name;
    }
    if (identity['network_secret'] case final String secret) {
      network.networkSecret = secret;
    }
  }

  if (config['netns'] case final String netns) {
    network.netNamespace = netns;
  }

  if (config['ipv4'] case final String ipv4) {
    network.ipv4 = ipv4;
  }

  if (config['ipv6'] case final String ipv6) {
    network.ipv6 = ipv6;
  }

  if (config['ipv6_public_addr_provider'] case final bool provider) {
    network.ipv6PublicAddressProvider = provider;
  }

  if (config['ipv6_public_addr_auto'] case final bool auto) {
    network.ipv6PublicAddressAuto = auto;
  }

  if (config['ipv6_public_addr_prefix'] case final String prefix) {
    network.ipv6PublicAddressPrefix = prefix;
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

  if (config['listeners'] case final List<dynamic> listeners) {
    network.listeners = [
      for (final item in listeners) Uri.parse(item.toString()),
    ];
  }

  if (config['mapped_listeners'] case final List<dynamic> mappedListeners) {
    network.mappedListeners = [
      for (final item in mappedListeners) Uri.parse(item.toString()),
    ];
  }

  if (config['exit_nodes'] case final List<dynamic> exitNodes) {
    network.exitNodes = _stringList(exitNodes);
  }

  if (config['peer'] case final List<dynamic> peers) {
    network.nodes = _parsePeers(peers);
  }

  if (config['proxy_network'] case final List<dynamic> proxies) {
    network.proxyNetworks = [
      for (final item in proxies) _parseProxyNetwork(item as Map),
    ];
  }

  if (config['routes'] case final List<dynamic> routes) {
    network.routes = _stringList(routes);
  }

  if (config['socks5_proxy'] case final String proxy) {
    network.socks5Proxy = Uri.parse(proxy);
  }

  if (config['port_forward'] case final List<dynamic> forwards) {
    network.portForwards = [
      for (final item in forwards) _parsePortForward(item as Map),
    ];
  }

  if (config['vpn_portal_config'] case final Map<dynamic, dynamic> portal) {
    network.vpnPortal = _parseVpnPortal(portal);
  }

  if (config['secure_mode'] case final Map<dynamic, dynamic> secureMode) {
    network.secureMode = _parseSecureMode(secureMode);
  }

  if (config['acl'] case final Map<dynamic, dynamic> acl) {
    network.acl = Map<String, Object?>.from(acl);
  }

  if (config['tcp_whitelist'] case final List<dynamic> whitelist) {
    network.tcpWhitelist = _stringList(whitelist);
  }

  if (config['udp_whitelist'] case final List<dynamic> whitelist) {
    network.udpWhitelist = _stringList(whitelist);
  }

  if (config['stun_servers'] case final List<dynamic> servers) {
    network.stunServers = _stringList(servers);
  }

  if (config['tcp_stun_servers'] case final List<dynamic> servers) {
    network.tcpStunServers = _stringList(servers);
  }

  if (config['stun_servers_v6'] case final List<dynamic> servers) {
    network.stunServersV6 = _stringList(servers);
  }

  if (config['credential_file'] case final String credentialFile) {
    network.credentialFile = credentialFile;
  }

  if (config['managed_credentials'] case final List<dynamic> credentials) {
    network.managedCredentials = [
      for (final item in credentials) _parseManagedCredential(item as Map),
    ];
  }

  if (config['flags'] case final Map<dynamic, dynamic> rawFlags) {
    final flags = _TrackingMap(rawFlags);
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

List<String> _stringList(Object? value) =>
    value is List ? [for (final item in value) item.toString()] : [];

ProxyNetwork _parseProxyNetwork(Map<dynamic, dynamic> data) => ProxyNetwork(
  cidr: data['cidr'].toString(),
  mappedCidr: data['mapped_cidr']?.toString(),
  allow: _stringList(data['allow']),
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
      ? [
          for (final item in data['clients'] as List)
            _parseVpnPortalClient(item as Map<dynamic, dynamic>),
        ]
      : [],
);

VpnPortalClient _parseVpnPortalClient(Map<dynamic, dynamic> data) =>
    VpnPortalClient(
      name: data['name'].toString(),
      virtualIp: data['virtual_ip'].toString(),
      groups: _stringList(data['groups']),
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
      groups: _stringList(data['groups']),
      allowRelay: data['allow_relay'] as bool? ?? false,
      allowedProxyCidrs: _stringList(data['allowed_proxy_cidrs']),
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

  int? parseOptionalInt(Object? value) => switch (value) {
    String text => int.tryParse(text),
    int number => number,
    _ => null,
  };

  return NetworkFlags(
    defaultProtocol: switch (data['default_protocol']) {
      String protocol => _parseNodeProtocol(protocol) ?? NodeProtocol.tcp,
      _ => NodeProtocol.tcp,
    },
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
    compressionAlgorithm: switch (data['data_compress_algo']) {
      String algorithm => parseCompressionAlgorithm(algorithm),
      _ => CompressionAlgorithm.none,
    },
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
    foreignRelayBpsLimit: parseOptionalInt(data['foreign_relay_bps_limit']),
    multiThreadCount: data['multi_thread_count'] as int? ?? 2,
    encryptionAlgorithm: parseEncryptionAlgorithm(data['encryption_algorithm']),
    disableSymmetricHolePunching:
        data['disable_sym_hole_punching'] as bool? ?? false,
    dnsZone: data['tld_dns_zone']?.toString() ?? defaultDnsDomain,
    quicListenPort: data['quic_listen_port'] as int?,
    needP2p: data['need_p2p'] as bool? ?? false,
    instanceReceiveBpsLimit: parseOptionalInt(
      data['instance_recv_bps_limit'],
    ),
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
