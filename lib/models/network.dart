import 'package:json_annotation/json_annotation.dart';

import '../utils/validator.dart';
import 'network_flags.dart';
import 'network_components.dart';
import 'node.dart';

part 'network.g.dart';

@JsonSerializable(explicitToJson: true)
final class Network {
  Network({
    required this.networkName,
    required Iterable<Node> nodes,
    required this.flags,
    required this.createdAt,
    required this.updatedAt,
    this.hostname,
    this.networkSecret,
    this.netNamespace,
    this.ipv4,
    this.ipv6,
    this.ipv6PublicAddressProvider = false,
    this.ipv6PublicAddressAuto = false,
    this.ipv6PublicAddressPrefix,
    this.dhcp = true,
    Iterable<Uri> listeners = const [],
    Iterable<Uri> mappedListeners = const [],
    Iterable<String> exitNodes = const [],
    Iterable<ProxyNetwork> proxyNetworks = const [],
    this.vpnPortal,
    Iterable<String> routes = const [],
    this.socks5Proxy,
    Iterable<PortForward> portForwards = const [],
    this.secureMode,
    Map<String, Object?>? acl,
    Iterable<String> tcpWhitelist = const [],
    Iterable<String> udpWhitelist = const [],
    Iterable<String> stunServers = const [],
    Iterable<String> tcpStunServers = const [],
    Iterable<String> stunServersV6 = const [],
    this.credentialFile,
    Iterable<ManagedCredential> managedCredentials = const [],
    Map<String, Object?> additionalFlags = const {},
    Map<String, Object?> additionalConfiguration = const {},
  }) : nodes = List.unmodifiable(nodes),
       listeners = List.unmodifiable(listeners),
       mappedListeners = List.unmodifiable(mappedListeners),
       exitNodes = List.unmodifiable(exitNodes),
       proxyNetworks = List.unmodifiable(proxyNetworks),
       routes = List.unmodifiable(routes),
       portForwards = List.unmodifiable(portForwards),
       acl = acl == null ? null : freezeMap(acl),
       tcpWhitelist = List.unmodifiable(tcpWhitelist),
       udpWhitelist = List.unmodifiable(udpWhitelist),
       stunServers = List.unmodifiable(stunServers),
       tcpStunServers = List.unmodifiable(tcpStunServers),
       stunServersV6 = List.unmodifiable(stunServersV6),
       managedCredentials = List.unmodifiable(managedCredentials),
       additionalFlags = freezeMap(additionalFlags),
       additionalConfiguration = freezeMap(additionalConfiguration);

  factory Network.fromJson(Map<String, dynamic> json) =>
      _$NetworkFromJson(json);

  Map<String, dynamic> toJson() => _$NetworkToJson(this);

  final String? hostname;
  final String networkName;
  final String? networkSecret;
  final String? netNamespace;
  final String? ipv4;
  final String? ipv6;
  final bool ipv6PublicAddressProvider;
  final bool ipv6PublicAddressAuto;
  final String? ipv6PublicAddressPrefix;
  final bool dhcp;
  final List<Node> nodes;
  final List<Uri> listeners;
  final List<Uri> mappedListeners;
  final List<String> exitNodes;
  final List<ProxyNetwork> proxyNetworks;
  final VpnPortal? vpnPortal;
  final List<String> routes;
  final Uri? socks5Proxy;
  final List<PortForward> portForwards;
  final SecureMode? secureMode;
  final Map<String, Object?>? acl;
  final List<String> tcpWhitelist;
  final List<String> udpWhitelist;
  final List<String> stunServers;
  final List<String> tcpStunServers;
  final List<String> stunServersV6;
  final String? credentialFile;
  final List<ManagedCredential> managedCredentials;
  final NetworkFlags flags;
  final Map<String, Object?> additionalFlags;
  final Map<String, Object?> additionalConfiguration;
  final DateTime createdAt;
  final DateTime updatedAt;
}
