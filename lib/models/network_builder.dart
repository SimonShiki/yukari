import 'dart:io';

import '../utils/validator.dart';
import 'network_flags.dart';
import 'network.dart';
import 'network_components.dart';
import 'node.dart';

final class NetworkBuilder {
  NetworkBuilder()
    : networkName = 'default',
      createdAt = DateTime.now().toUtc();

  NetworkBuilder.from(Network network)
    : hostname = network.hostname,
      networkName = network.networkName,
      networkSecret = network.networkSecret,
      netNamespace = network.netNamespace,
      ipv4 = network.ipv4,
      ipv6 = network.ipv6,
      ipv6PublicAddressProvider = network.ipv6PublicAddressProvider,
      ipv6PublicAddressAuto = network.ipv6PublicAddressAuto,
      ipv6PublicAddressPrefix = network.ipv6PublicAddressPrefix,
      dhcp = network.dhcp,
      nodes = List.of(network.nodes),
      listeners = List.of(network.listeners),
      mappedListeners = List.of(network.mappedListeners),
      exitNodes = List.of(network.exitNodes),
      proxyNetworks = List.of(network.proxyNetworks),
      vpnPortal = network.vpnPortal,
      routes = List.of(network.routes),
      socks5Proxy = network.socks5Proxy,
      portForwards = List.of(network.portForwards),
      secureMode = network.secureMode,
      acl = network.acl == null ? null : Map.of(network.acl!),
      tcpWhitelist = List.of(network.tcpWhitelist),
      udpWhitelist = List.of(network.udpWhitelist),
      stunServers = List.of(network.stunServers),
      tcpStunServers = List.of(network.tcpStunServers),
      stunServersV6 = List.of(network.stunServersV6),
      credentialFile = network.credentialFile,
      managedCredentials = List.of(network.managedCredentials),
      flags = network.flags,
      additionalFlags = Map.of(network.additionalFlags),
      additionalConfiguration = Map.of(network.additionalConfiguration),
      createdAt = network.createdAt;

  String? hostname;
  String networkName;
  String? networkSecret;
  String? netNamespace;
  String? ipv4;
  String? ipv6;
  bool ipv6PublicAddressProvider = false;
  bool ipv6PublicAddressAuto = false;
  String? ipv6PublicAddressPrefix;
  bool dhcp = true;
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
  DateTime createdAt;

  Network build() {
    final normalizedNetworkName = networkName.trim();
    if (normalizedNetworkName.isEmpty) {
      throw ArgumentError.value(networkName, 'networkName', 'Cannot be empty');
    }
    final normalizedHostname = hostname?.trim();
    if (normalizedHostname != null && normalizedHostname.length > 32) {
      throw ArgumentError.value(
        hostname,
        'hostname',
        'Cannot exceed 32 characters',
      );
    }
    if (ipv4 != null) {
      validateCidr(ipv4!, 'ipv4');
    }
    if (ipv6 != null) {
      validateCidr(ipv6!, 'ipv6');
    }
    if (ipv6PublicAddressPrefix != null) {
      validateCidr(ipv6PublicAddressPrefix!, 'ipv6PublicAddressPrefix');
    }
    for (final route in routes) {
      validateCidr(route, 'routes');
    }
    for (final exitNode in exitNodes) {
      if (InternetAddress.tryParse(exitNode) == null) {
        throw ArgumentError.value(
          exitNode,
          'exitNodes',
          'Must use a valid IP address',
        );
      }
    }
    for (final listener in [...listeners, ...mappedListeners]) {
      if (!listener.hasScheme || nodeHost(listener).isEmpty) {
        throw ArgumentError.value(
          listener,
          'listeners',
          'Must use a valid URL',
        );
      }
    }
    if (socks5Proxy != null &&
        (!socks5Proxy!.hasScheme || nodeHost(socks5Proxy!).isEmpty)) {
      throw ArgumentError.value(
        socks5Proxy,
        'socks5Proxy',
        'Must use a valid URL',
      );
    }
    final nodeIds = nodes.map((node) => node.id).toSet();
    if (nodeIds.length != nodes.length) {
      throw ArgumentError.value(nodes, 'nodes', 'id must be unique');
    }
    validatePortableMap(acl, 'acl');
    validatePortableMap(additionalFlags, 'additionalFlags');
    validatePortableMap(additionalConfiguration, 'additionalConfiguration');
    return Network(
      hostname: normalizedHostname?.isEmpty == true ? null : normalizedHostname,
      networkName: normalizedNetworkName,
      networkSecret: networkSecret,
      netNamespace: netNamespace,
      ipv4: ipv4,
      ipv6: ipv6,
      ipv6PublicAddressProvider: ipv6PublicAddressProvider,
      ipv6PublicAddressAuto: ipv6PublicAddressAuto,
      ipv6PublicAddressPrefix: ipv6PublicAddressPrefix,
      dhcp: dhcp,
      nodes: nodes,
      listeners: listeners,
      mappedListeners: mappedListeners,
      exitNodes: exitNodes,
      proxyNetworks: proxyNetworks,
      vpnPortal: vpnPortal,
      routes: routes,
      socks5Proxy: socks5Proxy,
      portForwards: portForwards,
      secureMode: secureMode,
      acl: acl,
      tcpWhitelist: tcpWhitelist,
      udpWhitelist: udpWhitelist,
      stunServers: stunServers,
      tcpStunServers: tcpStunServers,
      stunServersV6: stunServersV6,
      credentialFile: credentialFile,
      managedCredentials: managedCredentials,
      flags: flags,
      additionalFlags: additionalFlags,
      additionalConfiguration: additionalConfiguration,
      createdAt: createdAt.toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
