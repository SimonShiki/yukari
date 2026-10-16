// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Network _$NetworkFromJson(Map<String, dynamic> json) =>
    Network(json['networkName'] as String)
      ..hostname = json['hostname'] as String?
      ..networkSecret = json['networkSecret'] as String?
      ..netNamespace = json['netNamespace'] as String?
      ..ipv4 = json['ipv4'] as String?
      ..ipv6 = json['ipv6'] as String?
      ..ipv6PublicAddressProvider = json['ipv6PublicAddressProvider'] as bool
      ..ipv6PublicAddressAuto = json['ipv6PublicAddressAuto'] as bool
      ..ipv6PublicAddressPrefix = json['ipv6PublicAddressPrefix'] as String?
      ..dhcp = json['dhcp'] as bool
      ..nodes = (json['nodes'] as List<dynamic>)
          .map((e) => Node.fromJson(e as Map<String, dynamic>))
          .toList()
      ..listeners = (json['listeners'] as List<dynamic>)
          .map((e) => Uri.parse(e as String))
          .toList()
      ..mappedListeners = (json['mappedListeners'] as List<dynamic>)
          .map((e) => Uri.parse(e as String))
          .toList()
      ..exitNodes = (json['exitNodes'] as List<dynamic>)
          .map((e) => e as String)
          .toList()
      ..proxyNetworks = (json['proxyNetworks'] as List<dynamic>)
          .map((e) => ProxyNetwork.fromJson(e as Map<String, dynamic>))
          .toList()
      ..vpnPortal = json['vpnPortal'] == null
          ? null
          : VpnPortal.fromJson(json['vpnPortal'] as Map<String, dynamic>)
      ..routes = (json['routes'] as List<dynamic>)
          .map((e) => e as String)
          .toList()
      ..socks5Proxy = json['socks5Proxy'] == null
          ? null
          : Uri.parse(json['socks5Proxy'] as String)
      ..portForwards = (json['portForwards'] as List<dynamic>)
          .map((e) => PortForward.fromJson(e as Map<String, dynamic>))
          .toList()
      ..secureMode = json['secureMode'] == null
          ? null
          : SecureMode.fromJson(json['secureMode'] as Map<String, dynamic>)
      ..acl = json['acl'] as Map<String, dynamic>?
      ..tcpWhitelist = (json['tcpWhitelist'] as List<dynamic>)
          .map((e) => e as String)
          .toList()
      ..udpWhitelist = (json['udpWhitelist'] as List<dynamic>)
          .map((e) => e as String)
          .toList()
      ..stunServers = (json['stunServers'] as List<dynamic>)
          .map((e) => e as String)
          .toList()
      ..tcpStunServers = (json['tcpStunServers'] as List<dynamic>)
          .map((e) => e as String)
          .toList()
      ..stunServersV6 = (json['stunServersV6'] as List<dynamic>)
          .map((e) => e as String)
          .toList()
      ..credentialFile = json['credentialFile'] as String?
      ..managedCredentials = (json['managedCredentials'] as List<dynamic>)
          .map((e) => ManagedCredential.fromJson(e as Map<String, dynamic>))
          .toList()
      ..flags = NetworkFlags.fromJson(json['flags'] as Map<String, dynamic>)
      ..additionalFlags = json['additionalFlags'] as Map<String, dynamic>
      ..additionalConfiguration =
          json['additionalConfiguration'] as Map<String, dynamic>
      ..autoStart = json['autoStart'] as bool
      ..createdAt = DateTime.parse(json['createdAt'] as String)
      ..updatedAt = DateTime.parse(json['updatedAt'] as String);

Map<String, dynamic> _$NetworkToJson(Network instance) => <String, dynamic>{
  'hostname': instance.hostname,
  'networkName': instance.networkName,
  'networkSecret': instance.networkSecret,
  'netNamespace': instance.netNamespace,
  'ipv4': instance.ipv4,
  'ipv6': instance.ipv6,
  'ipv6PublicAddressProvider': instance.ipv6PublicAddressProvider,
  'ipv6PublicAddressAuto': instance.ipv6PublicAddressAuto,
  'ipv6PublicAddressPrefix': instance.ipv6PublicAddressPrefix,
  'dhcp': instance.dhcp,
  'nodes': instance.nodes.map((e) => e.toJson()).toList(),
  'listeners': instance.listeners.map((e) => e.toString()).toList(),
  'mappedListeners': instance.mappedListeners.map((e) => e.toString()).toList(),
  'exitNodes': instance.exitNodes,
  'proxyNetworks': instance.proxyNetworks.map((e) => e.toJson()).toList(),
  'vpnPortal': instance.vpnPortal?.toJson(),
  'routes': instance.routes,
  'socks5Proxy': instance.socks5Proxy?.toString(),
  'portForwards': instance.portForwards.map((e) => e.toJson()).toList(),
  'secureMode': instance.secureMode?.toJson(),
  'acl': instance.acl,
  'tcpWhitelist': instance.tcpWhitelist,
  'udpWhitelist': instance.udpWhitelist,
  'stunServers': instance.stunServers,
  'tcpStunServers': instance.tcpStunServers,
  'stunServersV6': instance.stunServersV6,
  'credentialFile': instance.credentialFile,
  'managedCredentials': instance.managedCredentials
      .map((e) => e.toJson())
      .toList(),
  'flags': instance.flags.toJson(),
  'additionalFlags': instance.additionalFlags,
  'additionalConfiguration': instance.additionalConfiguration,
  'autoStart': instance.autoStart,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
