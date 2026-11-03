// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_flags.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NetworkFlags _$NetworkFlagsFromJson(Map<String, dynamic> json) => NetworkFlags(
  defaultProtocol:
      $enumDecodeNullable(_$NodeProtocolEnumMap, json['defaultProtocol']) ??
      NodeProtocol.tcp,
  deviceName: json['deviceName'] as String? ?? '',
  enableEncryption: json['enableEncryption'] as bool? ?? true,
  enableIpv6: json['enableIpv6'] as bool? ?? true,
  mtu: (json['mtu'] as num?)?.toInt() ?? 1380,
  latencyFirst: json['latencyFirst'] as bool? ?? false,
  enableExitNode: json['enableExitNode'] as bool? ?? false,
  proxyForwardBySystem: json['proxyForwardBySystem'] as bool? ?? false,
  noTun: json['noTun'] as bool? ?? false,
  useSmoltcp: json['useSmoltcp'] as bool? ?? false,
  relayNetworkWhitelist: json['relayNetworkWhitelist'] as String? ?? '*',
  disableP2p: json['disableP2p'] as bool? ?? false,
  p2pOnly: json['p2pOnly'] as bool? ?? false,
  lazyP2p: json['lazyP2p'] as bool? ?? false,
  relayAllPeerRpc: json['relayAllPeerRpc'] as bool? ?? false,
  disableTcpHolePunching: json['disableTcpHolePunching'] as bool? ?? false,
  disableUdpHolePunching: json['disableUdpHolePunching'] as bool? ?? false,
  multiThread: json['multiThread'] as bool? ?? true,
  compressionAlgorithm:
      $enumDecodeNullable(
        _$CompressionAlgorithmEnumMap,
        json['compressionAlgorithm'],
      ) ??
      CompressionAlgorithm.none,
  bindDevice: json['bindDevice'] as bool? ?? true,
  enableKcpProxy: json['enableKcpProxy'] as bool? ?? false,
  disableKcpInput: json['disableKcpInput'] as bool? ?? false,
  disableRelayKcp: json['disableRelayKcp'] as bool? ?? false,
  enableRelayForeignNetworkKcp:
      json['enableRelayForeignNetworkKcp'] as bool? ?? false,
  acceptDns: json['acceptDns'] as bool? ?? false,
  privateMode: json['privateMode'] as bool? ?? false,
  enableQuicProxy: json['enableQuicProxy'] as bool? ?? false,
  disableQuicInput: json['disableQuicInput'] as bool? ?? false,
  disableRelayQuic: json['disableRelayQuic'] as bool? ?? false,
  enableRelayForeignNetworkQuic:
      json['enableRelayForeignNetworkQuic'] as bool? ?? false,
  foreignRelayBpsLimit: (json['foreignRelayBpsLimit'] as num?)?.toInt(),
  multiThreadCount: (json['multiThreadCount'] as num?)?.toInt() ?? 2,
  encryptionAlgorithm:
      $enumDecodeNullable(
        _$EncryptionAlgorithmEnumMap,
        json['encryptionAlgorithm'],
      ) ??
      EncryptionAlgorithm.aesGcm,
  disableSymmetricHolePunching:
      json['disableSymmetricHolePunching'] as bool? ?? false,
  dnsZone: json['dnsZone'] as String? ?? 'et.net.',
  quicListenPort: (json['quicListenPort'] as num?)?.toInt(),
  needP2p: json['needP2p'] as bool? ?? false,
  instanceReceiveBpsLimit: (json['instanceReceiveBpsLimit'] as num?)?.toInt(),
  disableUpnp: json['disableUpnp'] as bool? ?? false,
  disableRelayData: json['disableRelayData'] as bool? ?? false,
  preferPeerRelay: json['preferPeerRelay'] as bool? ?? false,
  enableUdpBroadcastRelay: json['enableUdpBroadcastRelay'] as bool? ?? false,
  socketMark: (json['socketMark'] as num?)?.toInt(),
);

Map<String, dynamic> _$NetworkFlagsToJson(NetworkFlags instance) =>
    <String, dynamic>{
      'defaultProtocol': _$NodeProtocolEnumMap[instance.defaultProtocol]!,
      'deviceName': instance.deviceName,
      'enableEncryption': instance.enableEncryption,
      'enableIpv6': instance.enableIpv6,
      'mtu': instance.mtu,
      'latencyFirst': instance.latencyFirst,
      'enableExitNode': instance.enableExitNode,
      'proxyForwardBySystem': instance.proxyForwardBySystem,
      'noTun': instance.noTun,
      'useSmoltcp': instance.useSmoltcp,
      'relayNetworkWhitelist': instance.relayNetworkWhitelist,
      'disableP2p': instance.disableP2p,
      'p2pOnly': instance.p2pOnly,
      'lazyP2p': instance.lazyP2p,
      'relayAllPeerRpc': instance.relayAllPeerRpc,
      'disableTcpHolePunching': instance.disableTcpHolePunching,
      'disableUdpHolePunching': instance.disableUdpHolePunching,
      'multiThread': instance.multiThread,
      'compressionAlgorithm':
          _$CompressionAlgorithmEnumMap[instance.compressionAlgorithm]!,
      'bindDevice': instance.bindDevice,
      'enableKcpProxy': instance.enableKcpProxy,
      'disableKcpInput': instance.disableKcpInput,
      'disableRelayKcp': instance.disableRelayKcp,
      'enableRelayForeignNetworkKcp': instance.enableRelayForeignNetworkKcp,
      'acceptDns': instance.acceptDns,
      'privateMode': instance.privateMode,
      'enableQuicProxy': instance.enableQuicProxy,
      'disableQuicInput': instance.disableQuicInput,
      'disableRelayQuic': instance.disableRelayQuic,
      'enableRelayForeignNetworkQuic': instance.enableRelayForeignNetworkQuic,
      'foreignRelayBpsLimit': instance.foreignRelayBpsLimit,
      'multiThreadCount': instance.multiThreadCount,
      'encryptionAlgorithm':
          _$EncryptionAlgorithmEnumMap[instance.encryptionAlgorithm]!,
      'disableSymmetricHolePunching': instance.disableSymmetricHolePunching,
      'dnsZone': instance.dnsZone,
      'quicListenPort': instance.quicListenPort,
      'needP2p': instance.needP2p,
      'instanceReceiveBpsLimit': instance.instanceReceiveBpsLimit,
      'disableUpnp': instance.disableUpnp,
      'disableRelayData': instance.disableRelayData,
      'preferPeerRelay': instance.preferPeerRelay,
      'enableUdpBroadcastRelay': instance.enableUdpBroadcastRelay,
      'socketMark': instance.socketMark,
    };

const _$NodeProtocolEnumMap = {
  NodeProtocol.tcp: 'tcp',
  NodeProtocol.udp: 'udp',
  NodeProtocol.ws: 'ws',
  NodeProtocol.wss: 'wss',
  NodeProtocol.quic: 'quic',
  NodeProtocol.wg: 'wg',
};

const _$CompressionAlgorithmEnumMap = {
  CompressionAlgorithm.none: 'none',
  CompressionAlgorithm.zstd: 'zstd',
};

const _$EncryptionAlgorithmEnumMap = {
  EncryptionAlgorithm.xor: 'xor',
  EncryptionAlgorithm.aesGcm: 'aesGcm',
  EncryptionAlgorithm.aes256Gcm: 'aes256Gcm',
  EncryptionAlgorithm.chacha20: 'chacha20',
};
