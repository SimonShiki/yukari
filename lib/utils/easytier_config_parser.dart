import 'package:toml/toml.dart';

import '../models/models.dart';

Network parseEasyTierConfig(String tomlContent) {
  final doc = TomlDocument.parse(tomlContent);
  final config = doc.toMap();

  final builder = NetworkBuilder();

  if (config['hostname'] is String) {
    builder.hostname = config['hostname'] as String;
  }

  if (config['network_identity'] is Map) {
    final identity = config['network_identity'] as Map;
    if (identity['network_name'] is String) {
      builder.networkName = identity['network_name'] as String;
    }
    if (identity['network_secret'] is String) {
      builder.networkSecret = identity['network_secret'] as String;
    }
  }

  if (config['netns'] is String) {
    builder.netNamespace = config['netns'] as String;
  }

  if (config['ipv4'] is String) {
    builder.ipv4 = config['ipv4'] as String;
  }

  if (config['ipv6'] is String) {
    builder.ipv6 = config['ipv6'] as String;
  }

  if (config['ipv6_public_addr_provider'] is bool) {
    builder.ipv6PublicAddressProvider = config['ipv6_public_addr_provider'] as bool;
  }

  if (config['ipv6_public_addr_auto'] is bool) {
    builder.ipv6PublicAddressAuto = config['ipv6_public_addr_auto'] as bool;
  }

  if (config['ipv6_public_addr_prefix'] is String) {
    builder.ipv6PublicAddressPrefix = config['ipv6_public_addr_prefix'] as String;
  }

  if (config['dhcp'] is bool) {
    builder.dhcp = config['dhcp'] as bool;
  }

  if (config['listeners'] is List) {
    builder.listeners = (config['listeners'] as List)
        .map((e) => Uri.parse(e.toString()))
        .toList();
  }

  if (config['mapped_listeners'] is List) {
    builder.mappedListeners = (config['mapped_listeners'] as List)
        .map((e) => Uri.parse(e.toString()))
        .toList();
  }

  if (config['exit_nodes'] is List) {
    builder.exitNodes = (config['exit_nodes'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['peer'] is List) {
    builder.nodes = _parsePeers(config['peer'] as List);
  }

  if (config['proxy_network'] is List) {
    builder.proxyNetworks = (config['proxy_network'] as List)
        .map((e) => _parseProxyNetwork(e as Map))
        .toList();
  }

  if (config['routes'] is List) {
    builder.routes = (config['routes'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['socks5_proxy'] is String) {
    builder.socks5Proxy = Uri.parse(config['socks5_proxy'] as String);
  }

  if (config['port_forward'] is List) {
    builder.portForwards = (config['port_forward'] as List)
        .map((e) => _parsePortForward(e as Map))
        .toList();
  }

  if (config['vpn_portal_config'] is Map) {
    builder.vpnPortal = _parseVpnPortal(config['vpn_portal_config'] as Map);
  }

  if (config['secure_mode'] is Map) {
    builder.secureMode = _parseSecureMode(config['secure_mode'] as Map);
  }

  if (config['acl'] is Map) {
    builder.acl = Map<String, Object?>.from(config['acl'] as Map);
  }

  if (config['tcp_whitelist'] is List) {
    builder.tcpWhitelist = (config['tcp_whitelist'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['udp_whitelist'] is List) {
    builder.udpWhitelist = (config['udp_whitelist'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['stun_servers'] is List) {
    builder.stunServers = (config['stun_servers'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['tcp_stun_servers'] is List) {
    builder.tcpStunServers = (config['tcp_stun_servers'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['stun_servers_v6'] is List) {
    builder.stunServersV6 = (config['stun_servers_v6'] as List)
        .map((e) => e.toString())
        .toList();
  }

  if (config['credential_file'] is String) {
    builder.credentialFile = config['credential_file'] as String;
  }

  if (config['managed_credentials'] is List) {
    builder.managedCredentials = (config['managed_credentials'] as List)
        .map((e) => _parseManagedCredential(e as Map))
        .toList();
  }

  if (config['flags'] is Map) {
    builder.flags = _parseFlags(config['flags'] as Map);
  }

  return builder.build();
}

List<Node> _parsePeers(List<dynamic> peers) {
  final nodeMap = <String, _NodeBuilder>{};

  for (final peer in peers) {
    if (peer is! Map) continue;

    final uriStr = peer['uri']?.toString();
    if (uriStr == null) continue;

    final uri = Uri.parse(uriStr);
    final host = uri.host;
    final port = uri.port;
    final protocol = _parseNodeProtocol(uri.scheme);
    final publicKey = peer['peer_public_key']?.toString();

    if (protocol == null || host.isEmpty || port == 0) continue;

    final nodeId = '$host:$port';
    final nodeBuilder = nodeMap.putIfAbsent(
      nodeId,
      () => _NodeBuilder(host: host, port: port, publicKey: publicKey),
    );

    nodeBuilder.protocols.add(protocol);
  }

  return nodeMap.entries.map((entry) {
    final builder = entry.value;
    return Node(
      id: entry.key,
      url: Uri(host: builder.host),
      port: builder.port,
      protocols: builder.protocols,
      publicKey: builder.publicKey,
    );
  }).toList();
}

class _NodeBuilder {
  _NodeBuilder({required this.host, required this.port, this.publicKey});

  final String host;
  final int port;
  final String? publicKey;
  final Set<NodeProtocol> protocols = {};
}

NodeProtocol? _parseNodeProtocol(String scheme) => switch (scheme.toLowerCase()) {
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
  wireguardListen: data['wireguard_listen'].toString(),
  wireguardPrivateKey: data['wireguard_private_key']?.toString(),
  clients: data['clients'] is List
      ? (data['clients'] as List).map((e) => _parseVpnPortalClient(e as Map<dynamic, dynamic>)).toList()
      : [],
);

VpnPortalClient _parseVpnPortalClient(Map<dynamic, dynamic> data) => VpnPortalClient(
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

ManagedCredential _parseManagedCredential(Map<dynamic, dynamic> data) => ManagedCredential(
  id: data['credential_id'].toString(),
  secret: data['credential_secret'].toString(),
  expiryUnix: data['expiry_unix'] as int,
  groups: data['groups'] is List
      ? (data['groups'] as List).map((e) => e.toString()).toList()
      : [],
  allowRelay: data['allow_relay'] as bool? ?? false,
  allowedProxyCidrs: data['allowed_proxy_cidrs'] is List
      ? (data['allowed_proxy_cidrs'] as List).map((e) => e.toString()).toList()
      : [],
  reusable: data['reusable'] as bool? ?? true,
);

NetworkFlags _parseFlags(Map<dynamic, dynamic> data) {
  CompressionAlgorithm parseCompressionAlgorithm(String value) =>
      switch (value.toLowerCase()) {
    'zstd' => CompressionAlgorithm.zstd,
    _ => CompressionAlgorithm.none,
  };

  EncryptionAlgorithm parseEncryptionAlgorithm(String value) =>
      switch (value.toLowerCase()) {
    'aes-gcm' => EncryptionAlgorithm.aesGcm,
    'aes-256-gcm' => EncryptionAlgorithm.aes256Gcm,
    'chacha20' => EncryptionAlgorithm.chacha20,
    'xor' => EncryptionAlgorithm.xor,
    _ => EncryptionAlgorithm.aesGcm,
  };

  return NetworkFlags(
    defaultProtocol: data['default_protocol'] is String
        ? _parseNodeProtocol(data['default_protocol'] as String) ?? NodeProtocol.tcp
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
    enableRelayForeignNetworkKcp: data['enable_relay_foreign_network_kcp'] as bool? ?? false,
    acceptDns: data['accept_dns'] as bool? ?? false,
    privateMode: data['private_mode'] as bool? ?? false,
    enableQuicProxy: data['enable_quic_proxy'] as bool? ?? false,
    disableQuicInput: data['disable_quic_input'] as bool? ?? false,
    disableRelayQuic: data['disable_relay_quic'] as bool? ?? false,
    enableRelayForeignNetworkQuic: data['enable_relay_foreign_network_quic'] as bool? ?? false,
    foreignRelayBpsLimit: data['foreign_relay_bps_limit'] is String
        ? int.tryParse(data['foreign_relay_bps_limit'] as String)
        : data['foreign_relay_bps_limit'] as int?,
    multiThreadCount: data['multi_thread_count'] as int? ?? 2,
    encryptionAlgorithm: data['encryption_algorithm'] is String
        ? parseEncryptionAlgorithm(data['encryption_algorithm'] as String)
        : EncryptionAlgorithm.aesGcm,
    disableSymmetricHolePunching: data['disable_sym_hole_punching'] as bool? ?? false,
    dnsZone: data['tld_dns_zone']?.toString() ?? 'et.net.',
    quicListenPort: data['quic_listen_port'] as int?,
    needP2p: data['need_p2p'] as bool? ?? false,
    instanceReceiveBpsLimit: data['instance_recv_bps_limit'] is String
        ? int.tryParse(data['instance_recv_bps_limit'] as String)
        : data['instance_recv_bps_limit'] as int?,
    disableUpnp: data['disable_upnp'] as bool? ?? false,
    disableRelayData: data['disable_relay_data'] as bool? ?? false,
    preferPeerRelay: data['prefer_peer_relay'] as bool? ?? false,
    enableUdpBroadcastRelay: data['enable_udp_broadcast_relay'] as bool? ?? false,
    socketMark: data['socket_mark'] as int?,
  );
}
