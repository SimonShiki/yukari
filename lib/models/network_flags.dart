import 'package:json_annotation/json_annotation.dart';

import 'node.dart';

part 'network_flags.g.dart';

enum CompressionAlgorithm { none, zstd }

enum EncryptionAlgorithm { xor, aesGcm, aes256Gcm, chacha20 }

@JsonSerializable()
class NetworkFlags {
  NetworkFlags({
    this.defaultProtocol = NodeProtocol.tcp,
    this.deviceName = '',
    this.enableEncryption = true,
    this.enableIpv6 = true,
    this.mtu = 1380,
    this.latencyFirst = false,
    this.enableExitNode = false,
    this.proxyForwardBySystem = false,
    this.noTun = false,
    this.useSmoltcp = false,
    this.relayNetworkWhitelist = '*',
    this.disableP2p = false,
    this.p2pOnly = false,
    this.lazyP2p = false,
    this.relayAllPeerRpc = false,
    this.disableTcpHolePunching = false,
    this.disableUdpHolePunching = false,
    this.multiThread = true,
    this.compressionAlgorithm = CompressionAlgorithm.none,
    this.bindDevice = true,
    this.enableKcpProxy = false,
    this.disableKcpInput = false,
    this.disableRelayKcp = false,
    this.enableRelayForeignNetworkKcp = false,
    this.acceptDns = false,
    this.privateMode = false,
    this.enableQuicProxy = false,
    this.disableQuicInput = false,
    this.disableRelayQuic = false,
    this.enableRelayForeignNetworkQuic = false,
    this.foreignRelayBpsLimit,
    this.multiThreadCount = 2,
    this.encryptionAlgorithm = EncryptionAlgorithm.aesGcm,
    this.disableSymmetricHolePunching = false,
    this.dnsZone = 'et.net.',
    this.quicListenPort,
    this.needP2p = false,
    this.instanceReceiveBpsLimit,
    this.disableUpnp = false,
    this.disableRelayData = false,
    this.preferPeerRelay = false,
    this.enableUdpBroadcastRelay = false,
    this.socketMark,
  }) {
    if (mtu < 576 || mtu > 65535) {
      throw RangeError.range(mtu, 576, 65535, 'mtu');
    }
    if (multiThreadCount < 1) {
      throw RangeError.range(multiThreadCount, 1, null, 'multiThreadCount');
    }
    if (quicListenPort != null &&
        (quicListenPort! < 1 || quicListenPort! > 65535)) {
      throw RangeError.range(quicListenPort!, 1, 65535, 'quicListenPort');
    }
  }

  NodeProtocol defaultProtocol;
  String deviceName;
  bool enableEncryption;
  bool enableIpv6;
  int mtu;
  bool latencyFirst;
  bool enableExitNode;
  bool proxyForwardBySystem;
  bool noTun;
  bool useSmoltcp;
  String relayNetworkWhitelist;
  bool disableP2p;
  bool p2pOnly;
  bool lazyP2p;
  bool relayAllPeerRpc;
  bool disableTcpHolePunching;
  bool disableUdpHolePunching;
  bool multiThread;
  CompressionAlgorithm compressionAlgorithm;
  bool bindDevice;
  bool enableKcpProxy;
  bool disableKcpInput;
  bool disableRelayKcp;
  bool enableRelayForeignNetworkKcp;
  bool acceptDns;
  bool privateMode;
  bool enableQuicProxy;
  bool disableQuicInput;
  bool disableRelayQuic;
  bool enableRelayForeignNetworkQuic;
  int? foreignRelayBpsLimit;
  int multiThreadCount;
  EncryptionAlgorithm encryptionAlgorithm;
  bool disableSymmetricHolePunching;
  String dnsZone;
  int? quicListenPort;
  bool needP2p;
  int? instanceReceiveBpsLimit;
  bool disableUpnp;
  bool disableRelayData;
  bool preferPeerRelay;
  bool enableUdpBroadcastRelay;
  int? socketMark;

  factory NetworkFlags.fromJson(Map<String, dynamic> json) =>
      _$NetworkFlagsFromJson(json);

  Map<String, dynamic> toJson() => _$NetworkFlagsToJson(this);
}
