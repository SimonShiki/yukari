import 'package:json_annotation/json_annotation.dart';

import 'network_flags.dart';
import 'network_components.dart';
import 'node.dart';

part 'network.g.dart';

/// A saved network configuration. Fields are edited in place; validation is
/// the responsibility of whoever writes them (see `utils/validator.dart`).
@JsonSerializable(explicitToJson: true)
final class Network {
  Network();

  factory Network.fromJson(Map<String, dynamic> json) =>
      _$NetworkFromJson(json);

  Map<String, dynamic> toJson() => _$NetworkToJson(this);

  /// A deep, independent copy of this network.
  Network copy() => Network.fromJson(toJson())
    ..acl = acl == null ? null : _copyMap(acl!)
    ..additionalFlags = _copyMap(additionalFlags)
    ..additionalConfiguration = _copyMap(additionalConfiguration);

  String? hostname;
  String networkName = 'youkai-boundaries';
  String? networkSecret;
  String? netNamespace;
  String? ipv4;
  String? ipv6;
  bool ipv6PublicAddressProvider = false;
  bool ipv6PublicAddressAuto = false;
  String? ipv6PublicAddressPrefix;
  bool dhcp = true;

  /// Optional subnet EasyTier uses when assigning IPv4 addresses by DHCP.
  String? dhcpIpv4Cidr;
  List<Node> nodes = [];
  List<Uri> listeners = [];
  List<Uri> mappedListeners = [];
  List<String> exitNodes = [];
  List<ProxyNetwork> proxyNetworks = [];
  VpnPortal? vpnPortal;
  List<String> routes = [];
  Uri? socks5Proxy;
  List<PortForward> portForwards = [];
  SecureMode? secureMode;
  Map<String, Object?>? acl;
  List<String> tcpWhitelist = [];
  List<String> udpWhitelist = [];
  List<String> stunServers = [];
  List<String> tcpStunServers = [];
  List<String> stunServersV6 = [];
  String? credentialFile;
  List<ManagedCredential> managedCredentials = [];
  NetworkFlags flags = NetworkFlags();
  Map<String, Object?> additionalFlags = {};
  Map<String, Object?> additionalConfiguration = {};

  /// Whether the background service runs this network when the system boots.
  bool autoStart = false;
  DateTime createdAt = DateTime.now().toUtc();
  DateTime updatedAt = DateTime.now().toUtc();
}

Map<String, Object?> _copyMap(Map<String, Object?> value) => {
  for (final entry in value.entries) entry.key: _copyValue(entry.value),
};

Object? _copyValue(Object? value) => switch (value) {
  Map<String, Object?> map => _copyMap(map),
  List<Object?> list => list.map(_copyValue).toList(),
  _ => value,
};
