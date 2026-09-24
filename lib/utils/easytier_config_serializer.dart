import 'package:toml/toml.dart';

import '../models/models.dart';

String _serialize(Network network) {
  final configuration = <String, Object?>{
    'dhcp': network.dhcp,
    'ipv6_public_addr_provider': network.ipv6PublicAddressProvider,
    'ipv6_public_addr_auto': network.ipv6PublicAddressAuto,
    'network_identity': <String, Object?>{
      'network_name': network.networkName,
      if (network.networkSecret != null)
        'network_secret': network.networkSecret,
    },
    'listeners': network.listeners.map((value) => value.toString()).toList(),
    'mapped_listeners': network.mappedListeners
        .map((value) => value.toString())
        .toList(),
    'exit_nodes': network.exitNodes,
    'peer': [
      for (final node in network.nodes)
        for (final protocol in node.protocols)
          <String, Object?>{
            'uri': node.endpoint(protocol).toString(),
            if (node.publicKey != null) 'peer_public_key': node.publicKey,
          },
    ],
    'proxy_network': [
      for (final proxy in network.proxyNetworks)
        <String, Object?>{
          'cidr': proxy.cidr,
          if (proxy.mappedCidr != null) 'mapped_cidr': proxy.mappedCidr,
          if (proxy.allow.isNotEmpty) 'allow': proxy.allow,
        },
    ],
    'routes': network.routes,
    'port_forward': [
      for (final forward in network.portForwards)
        <String, Object?>{
          'proto': forward.protocol,
          'bind_addr': forward.bindAddress,
          'dst_addr': forward.destinationAddress,
        },
    ],
    'flags': _flags(network.flags, network.additionalFlags),
    'tcp_whitelist': network.tcpWhitelist,
    'udp_whitelist': network.udpWhitelist,
    'stun_servers': network.stunServers,
    'tcp_stun_servers': network.tcpStunServers,
    'stun_servers_v6': network.stunServersV6,
    'managed_credentials': [
      for (final credential in network.managedCredentials)
        <String, Object?>{
          'credential_id': credential.id,
          'credential_secret': credential.secret,
          'groups': credential.groups,
          'allow_relay': credential.allowRelay,
          'allowed_proxy_cidrs': credential.allowedProxyCidrs,
          'expiry_unix': credential.expiryUnix,
          'reusable': credential.reusable,
        },
    ],
    if (network.hostname != null) 'hostname': network.hostname,
    if (network.netNamespace != null) 'netns': network.netNamespace,
    if (network.ipv4 != null) 'ipv4': network.ipv4,
    if (network.ipv6 != null) 'ipv6': network.ipv6,
    if (network.ipv6PublicAddressPrefix != null)
      'ipv6_public_addr_prefix': network.ipv6PublicAddressPrefix,
    if (network.vpnPortal != null)
      'vpn_portal_config': _vpnPortal(network.vpnPortal!),
    if (network.socks5Proxy != null)
      'socks5_proxy': network.socks5Proxy.toString(),
    if (network.secureMode != null)
      'secure_mode': _secureMode(network.secureMode!),
    if (network.acl != null) 'acl': network.acl,
    if (network.credentialFile != null)
      'credential_file': network.credentialFile,
  };
  for (final entry in network.additionalConfiguration.entries) {
    if (entry.key == 'instance_id' || entry.key == 'instance_name') continue;
    if (configuration.containsKey(entry.key)) {
      throw StateError(
        'additionalConfiguration contains reserved key ${entry.key}',
      );
    }
    configuration[entry.key] = entry.value;
  }
  return TomlDocument.fromMap(configuration).toString();
}

Map<String, Object?> _flags(
  NetworkFlags flags,
  Map<String, Object?> additional,
) {
  final values = <String, Object?>{
    'default_protocol': flags.defaultProtocol.name,
    'dev_name': flags.deviceName,
    'enable_encryption': flags.enableEncryption,
    'enable_ipv6': flags.enableIpv6,
    'mtu': flags.mtu,
    'latency_first': flags.latencyFirst,
    'enable_exit_node': flags.enableExitNode,
    'proxy_forward_by_system': flags.proxyForwardBySystem,
    'no_tun': flags.noTun,
    'use_smoltcp': flags.useSmoltcp,
    'relay_network_whitelist': flags.relayNetworkWhitelist,
    'disable_p2p': flags.disableP2p,
    'p2p_only': flags.p2pOnly,
    'lazy_p2p': flags.lazyP2p,
    'relay_all_peer_rpc': flags.relayAllPeerRpc,
    'disable_tcp_hole_punching': flags.disableTcpHolePunching,
    'disable_udp_hole_punching': flags.disableUdpHolePunching,
    'multi_thread': flags.multiThread,
    'data_compress_algo': _compressionAlgorithm(flags.compressionAlgorithm),
    'bind_device': flags.bindDevice,
    'enable_kcp_proxy': flags.enableKcpProxy,
    'disable_kcp_input': flags.disableKcpInput,
    'disable_relay_kcp': flags.disableRelayKcp,
    'enable_relay_foreign_network_kcp': flags.enableRelayForeignNetworkKcp,
    'accept_dns': flags.acceptDns,
    'private_mode': flags.privateMode,
    'enable_quic_proxy': flags.enableQuicProxy,
    'disable_quic_input': flags.disableQuicInput,
    'disable_relay_quic': flags.disableRelayQuic,
    'enable_relay_foreign_network_quic': flags.enableRelayForeignNetworkQuic,
    'multi_thread_count': flags.multiThreadCount,
    'encryption_algorithm': _encryptionAlgorithm(flags.encryptionAlgorithm),
    'disable_sym_hole_punching': flags.disableSymmetricHolePunching,
    'tld_dns_zone': flags.dnsZone,
    'need_p2p': flags.needP2p,
    'disable_upnp': flags.disableUpnp,
    'disable_relay_data': flags.disableRelayData,
    'prefer_peer_relay': flags.preferPeerRelay,
    'enable_udp_broadcast_relay': flags.enableUdpBroadcastRelay,
    if (flags.foreignRelayBpsLimit != null)
      'foreign_relay_bps_limit': flags.foreignRelayBpsLimit.toString(),
    if (flags.quicListenPort != null) 'quic_listen_port': flags.quicListenPort,
    if (flags.instanceReceiveBpsLimit != null)
      'instance_recv_bps_limit': flags.instanceReceiveBpsLimit.toString(),
    if (flags.socketMark != null) 'socket_mark': flags.socketMark,
  };
  for (final entry in additional.entries) {
    if (values.containsKey(entry.key)) {
      throw StateError('additionalFlags contains reserved key ${entry.key}');
    }
    values[entry.key] = entry.value;
  }
  return values;
}

Map<String, Object?> _vpnPortal(VpnPortal portal) => <String, Object?>{
  'wireguard_listen': portal.wireguardListen,
  if (portal.wireguardPrivateKey != null)
    'wireguard_private_key': portal.wireguardPrivateKey,
  'clients': [
    for (final client in portal.clients)
      <String, Object?>{
        'name': client.name,
        'virtual_ip': client.virtualIp,
        'groups': client.groups,
      },
  ],
};

Map<String, Object?> _secureMode(SecureMode mode) => <String, Object?>{
  'enabled': mode.enabled,
  if (mode.localPrivateKey != null) 'local_private_key': mode.localPrivateKey,
  if (mode.localPublicKey != null) 'local_public_key': mode.localPublicKey,
};

String _compressionAlgorithm(CompressionAlgorithm value) => switch (value) {
  CompressionAlgorithm.none => 'None',
  CompressionAlgorithm.zstd => 'Zstd',
};

String _encryptionAlgorithm(EncryptionAlgorithm value) => switch (value) {
  EncryptionAlgorithm.xor => 'xor',
  EncryptionAlgorithm.aesGcm => 'aes-gcm',
  EncryptionAlgorithm.aes256Gcm => 'aes-256-gcm',
  EncryptionAlgorithm.chacha20 => 'chacha20',
};

extension EasyTierNetworkSerialization on Network {
  String toEasyTierToml() => _serialize(this);
}
