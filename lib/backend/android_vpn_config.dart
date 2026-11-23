import 'package:flutter/foundation.dart' show listEquals;
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/system/magic_dns.dart';

import 'android_vpn_ip.dart';

export 'android_vpn_ip.dart'
    show cidrsOverlap, ipNetworkCidr, parseAssignedAddresses;

const _magicDnsRoute = '$magicDnsServer/32';

/// One TUN-enabled network participating in Android's shared VPN interface.
final class AndroidVpnMember {
  const AndroidVpnMember({
    required this.network,
    this.assignedIpv4,
    this.assignedIpv6,
  });

  final Network network;
  final String? assignedIpv4;
  final String? assignedIpv6;

  AndroidVpnMember withAssignedAddresses({String? ipv4, String? ipv6}) =>
      AndroidVpnMember(
        network: network,
        assignedIpv4: ipv4 ?? assignedIpv4,
        assignedIpv6: ipv6 ?? assignedIpv6,
      );

  /// The virtual IPv4/IPv6 host CIDRs configured or assigned for this member.
  List<String> get effectiveAddresses {
    final result = <String>[];
    final ipv4 = _effectiveIpv4();
    if (ipv4 != null) result.add(ipv4);
    final ipv6 = _effectiveIpv6();
    if (ipv6 != null) result.add(ipv6);
    return result;
  }

  /// Network routes owned by this member.
  List<String> get claimedRoutes => [
    for (final address in effectiveAddresses) ipNetworkCidr(address),
    for (final proxy in network.proxyNetworks) ipNetworkCidr(proxy.cidr),
  ];

  String? _effectiveIpv4() {
    if (assignedIpv4 case final ipv4? when ipv4.isNotEmpty) {
      return ensureCidr(ipv4, defaultPrefix: 24);
    }
    if (network.ipv4 case final ipv4? when ipv4.isNotEmpty) {
      return ensureCidr(ipv4, defaultPrefix: 24);
    }
    if (network.dhcp) return bootstrapDhcpIpv4(network.dhcpIpv4Cidr);
    if ((network.ipv6 == null || network.ipv6!.isEmpty) &&
        (assignedIpv6 == null || assignedIpv6!.isEmpty)) {
      return !network.dhcpv6 ? bootstrapDhcpIpv4(network.dhcpIpv4Cidr) : null;
    }
    return null;
  }

  String? _effectiveIpv6() {
    if (assignedIpv6 case final ipv6? when ipv6.isNotEmpty) {
      return ensureCidr(ipv6, defaultPrefix: 64);
    }
    if (network.ipv6 case final ipv6? when ipv6.isNotEmpty) {
      return ensureCidr(ipv6, defaultPrefix: 64);
    }
    if (network.dhcpv6) return bootstrapDhcpIpv6(network.dhcpIpv6Cidr);
    return null;
  }
}

/// The aggregated VPN interface configuration for one or more Android TUN networks.
final class AndroidVpnConfig {
  const AndroidVpnConfig({
    required this.networkNames,
    required this.addresses,
    required this.mtu,
    required this.routes,
    this.dns,
  });

  final List<String> networkNames;
  final List<String> addresses;
  final int mtu;
  final List<String> routes;
  final String? dns;

  @override
  bool operator ==(Object other) =>
      other is AndroidVpnConfig &&
      mtu == other.mtu &&
      dns == other.dns &&
      listEquals(addresses, other.addresses) &&
      listEquals(routes, other.routes);

  @override
  int get hashCode =>
      Object.hash(mtu, dns, Object.hashAll(addresses), Object.hashAll(routes));
}

/// Builds the single-network VPN request for [network].
AndroidVpnConfig androidVpnRequest(Network network) =>
    buildAndroidVpnConfig([AndroidVpnMember(network: network)]);

/// Aggregates [members] into one Android `VpnService` configuration.
AndroidVpnConfig buildAndroidVpnConfig(Iterable<AndroidVpnMember> members) {
  final addresses = <String>{};
  final routes = <String>{};
  final names = <String>[];
  var magicDns = false;
  int? minMtu;

  for (final member in members) {
    names.add(member.network.networkName);
    final memberAddresses = member.effectiveAddresses;
    addresses.addAll(memberAddresses);
    for (final address in memberAddresses) {
      routes.add(ipNetworkCidr(address));
    }
    for (final proxy in member.network.proxyNetworks) {
      routes.add(ipNetworkCidr(proxy.cidr));
    }
    magicDns |= magicDnsRequested(member.network.flags);
    final mtu = member.network.flags.mtu;
    if (minMtu == null || mtu < minMtu) minMtu = mtu;
  }
  if (magicDns) routes.add(_magicDnsRoute);

  return AndroidVpnConfig(
    networkNames: names,
    addresses: addresses.toList()..sort(),
    mtu: minMtu ?? 1420,
    routes: routes.toList()..sort(),
    dns: magicDns ? magicDnsServer : null,
  );
}

/// Returns a conflict description when [candidate] overlaps an existing route.
String? findVpnRouteConflict(
  Iterable<AndroidVpnMember> existing,
  AndroidVpnMember candidate,
) {
  final candidateRoutes = candidate.claimedRoutes;
  final magicDnsInUse =
      magicDnsRequested(candidate.network.flags) ||
      existing.any((member) => magicDnsRequested(member.network.flags));

  if (magicDnsInUse) {
    for (final route in candidateRoutes) {
      if (cidrsOverlap(_magicDnsRoute, route)) {
        return 'Route $route overlaps with shared Magic DNS route';
      }
    }
  }
  for (final member in existing) {
    if (member.network.networkName == candidate.network.networkName) continue;
    final existingRoutes = member.claimedRoutes;
    for (final existingRoute in existingRoutes) {
      for (final candidateRoute in candidateRoutes) {
        if (cidrsOverlap(existingRoute, candidateRoute)) {
          return 'Route $candidateRoute overlaps with $existingRoute '
              'owned by ${member.network.networkName}';
        }
      }
    }
    if (magicDnsInUse) {
      for (final route in existingRoutes) {
        if (cidrsOverlap(_magicDnsRoute, route)) {
          return 'Route $route overlaps with shared Magic DNS route';
        }
      }
    }
  }
  return null;
}
