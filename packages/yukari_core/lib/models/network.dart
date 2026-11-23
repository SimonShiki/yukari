import 'package:json_annotation/json_annotation.dart';

import 'network_flags.dart';
import 'network_components.dart';
import 'node.dart';
import '../utils/dns_name.dart';

part 'network.g.dart';

/// A saved network configuration. Fields are edited in place, and whoever
/// writes them validates them (see `utils/validator.dart`).
@JsonSerializable(explicitToJson: true)
final class Network {
  Network({
    this.hostname,
    this.networkName = 'youkai-boundaries',
    this.networkSecret,
    this.netNamespace,
    this.ipv4,
    this.ipv6,
    this.ipv6PublicAddressProvider = false,
    this.ipv6PublicAddressAuto = false,
    this.ipv6PublicAddressPrefix,
    this.dhcp = true,
    this.dhcpIpv4Cidr,
    this.dhcpv6 = false,
    this.dhcpIpv6Cidr,
    this.dns,
    List<Node>? nodes,
    List<Uri>? listeners,
    List<Uri>? mappedListeners,
    List<String>? exitNodes,
    List<ProxyNetwork>? proxyNetworks,
    this.vpnPortal,
    List<String>? routes,
    this.socks5Proxy,
    List<PortForward>? portForwards,
    this.secureMode,
    this.acl,
    List<String>? tcpWhitelist,
    List<String>? udpWhitelist,
    List<String>? stunServers,
    List<String>? tcpStunServers,
    List<String>? stunServersV6,
    this.credentialFile,
    List<ManagedCredential>? managedCredentials,
    NetworkFlags? flags,
    Map<String, Object?>? additionalFlags,
    Map<String, Object?>? additionalConfiguration,
    this.autoStart = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : nodes = nodes ?? [],
       listeners = listeners ?? [],
       mappedListeners = mappedListeners ?? [],
       exitNodes = exitNodes ?? [],
       proxyNetworks = proxyNetworks ?? [],
       routes = routes ?? [],
       portForwards = portForwards ?? [],
       tcpWhitelist = tcpWhitelist ?? [],
       udpWhitelist = udpWhitelist ?? [],
       stunServers = stunServers ?? [],
       tcpStunServers = tcpStunServers ?? [],
       stunServersV6 = stunServersV6 ?? [],
       managedCredentials = managedCredentials ?? [],
       flags = flags ?? NetworkFlags(),
       additionalFlags = additionalFlags ?? {},
       additionalConfiguration = additionalConfiguration ?? {},
       createdAt = createdAt ?? DateTime.now().toUtc(),
       updatedAt = updatedAt ?? DateTime.now().toUtc();

  factory Network.fromJson(Map<String, dynamic> json) =>
      _$NetworkFromJson(json);

  Map<String, dynamic> toJson() => _$NetworkToJson(this);

  /// A deep, independent copy of this network.
  Network copy() => Network.fromJson(toJson())
    ..acl = acl == null ? null : _copyMap(acl!)
    ..additionalFlags = _copyMap(additionalFlags)
    ..additionalConfiguration = _copyMap(additionalConfiguration);

  String? hostname;
  String networkName;
  String? networkSecret;
  String? netNamespace;
  String? ipv4;
  String? ipv6;
  bool ipv6PublicAddressProvider;
  bool ipv6PublicAddressAuto;
  String? ipv6PublicAddressPrefix;
  bool dhcp;

  /// Optional subnet EasyTier uses when assigning IPv4 addresses by DHCP.
  String? dhcpIpv4Cidr;
  bool dhcpv6;

  /// Optional subnet EasyTier uses when assigning IPv6 addresses by DHCPv6.
  String? dhcpIpv6Cidr;
  DnsConfig? dns;
  @JsonKey(fromJson: _nodesFromJson)
  List<Node> nodes;
  List<Uri> listeners;
  List<Uri> mappedListeners;
  List<String> exitNodes;
  List<ProxyNetwork> proxyNetworks;
  VpnPortal? vpnPortal;
  List<String> routes;
  Uri? socks5Proxy;
  List<PortForward> portForwards;
  SecureMode? secureMode;
  Map<String, Object?>? acl;
  List<String> tcpWhitelist;
  List<String> udpWhitelist;
  List<String> stunServers;
  List<String> tcpStunServers;
  List<String> stunServersV6;
  String? credentialFile;
  List<ManagedCredential> managedCredentials;
  NetworkFlags flags;
  Map<String, Object?> additionalFlags;
  Map<String, Object?> additionalConfiguration;

  /// Whether the background service runs this network when the system boots.
  bool autoStart;
  DateTime createdAt;
  DateTime updatedAt;

  /// Effective Magic DNS root domain for this network, preferring `[dns].domain`
  /// over the deprecated `flags.dnsZone` fallback.
  String get effectiveDnsDomain {
    final configured = dns?.domain?.trim() ?? '';
    if (configured.isNotEmpty) return configured;
    final legacy = flags.dnsZone.trim();
    return legacy.isNotEmpty ? legacy : defaultDnsDomain;
  }

  /// Deduplicated Magic DNS zones served by this network: [effectiveDnsDomain]
  /// first, followed by any configured static zone origins.
  List<String> get magicDnsZones {
    final seen = <String>{};
    final result = <String>[];
    void addZone(String raw) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return;
      final normalized = normalizeDnsName(trimmed);
      if (normalized.isEmpty || !seen.add(normalized)) return;
      result.add(trimmed);
    }

    addZone(effectiveDnsDomain);
    for (final zone in dns?.zones ?? const <DnsZone>[]) {
      addZone(zone.origin);
    }
    return result;
  }
}

Map<String, Object?> _copyMap(Map<String, Object?> value) => {
  for (final entry in value.entries) entry.key: _copyValue(entry.value),
};

Object? _copyValue(Object? value) => switch (value) {
  Map<String, Object?> map => _copyMap(map),
  List<Object?> list => list.map(_copyValue).toList(),
  _ => value,
};

List<Node> _nodesFromJson(List<dynamic>? entries) => [
  for (final entry in entries ?? const <dynamic>[])
    ...nodesFromJson(entry as Map<String, dynamic>),
];
