import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/system/magic_dns.dart';

const _defaultDhcpIpv4 = '10.126.126.1/24';
const _defaultDhcpIpv6 = 'fd6b:8c2d:91e4::1/64';
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

  /// Network routes owned by this member (excluding the shared Magic DNS `/32`).
  List<String> get claimedRoutes {
    final result = <String>[];
    for (final address in effectiveAddresses) {
      result.add(ipNetworkCidr(address));
    }
    for (final proxy in network.proxyNetworks) {
      result.add(ipNetworkCidr(proxy.cidr));
    }
    return result;
  }

  String? _effectiveIpv4() {
    if (assignedIpv4 case final ipv4? when ipv4.isNotEmpty) {
      return _ensureCidr(ipv4, defaultPrefix: 24);
    }
    if (network.ipv4 case final ipv4? when ipv4.isNotEmpty) {
      return _ensureCidr(ipv4, defaultPrefix: 24);
    }
    if ((network.ipv6 == null || network.ipv6!.isEmpty) &&
        (assignedIpv6 == null || assignedIpv6!.isEmpty)) {
      return network.dhcp || !network.dhcpv6
          ? _bootstrapDhcpIpv4(network.dhcpIpv4Cidr)
          : null;
    }
    return null;
  }

  String? _effectiveIpv6() {
    if (assignedIpv6 case final ipv6? when ipv6.isNotEmpty) {
      return _ensureCidr(ipv6, defaultPrefix: 64);
    }
    if (network.ipv6 case final ipv6? when ipv6.isNotEmpty) {
      return _ensureCidr(ipv6, defaultPrefix: 64);
    }
    if (network.dhcpv6) {
      return _bootstrapDhcpIpv6(network.dhcpIpv6Cidr);
    }
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
      _listEquals(addresses, other.addresses) &&
      _listEquals(routes, other.routes);

  @override
  int get hashCode => Object.hash(
    mtu,
    dns,
    Object.hashAll(addresses),
    Object.hashAll(routes),
  );
}

/// Builds the single-network VPN request for [network].
AndroidVpnConfig androidVpnRequest(Network network) =>
    buildAndroidVpnConfig([AndroidVpnMember(network: network)]);

/// Aggregates [members] into one Android `VpnService` configuration.
AndroidVpnConfig buildAndroidVpnConfig(Iterable<AndroidVpnMember> members) {
  final list = members.toList();
  final addresses = <String>{};
  final routes = <String>{};
  final names = <String>[];
  var magicDns = false;
  int? minMtu;

  for (final member in list) {
    names.add(member.network.networkName);
    addresses.addAll(member.effectiveAddresses);
    routes.addAll(member.claimedRoutes);
    if (magicDnsRequested(member.network.flags)) {
      magicDns = true;
    }
    final mtu = member.network.flags.mtu;
    if (minMtu == null || mtu < minMtu) {
      minMtu = mtu;
    }
  }
  if (magicDns) {
    routes.add(_magicDnsRoute);
  }

  return AndroidVpnConfig(
    networkNames: names,
    addresses: addresses.toList()..sort(),
    mtu: minMtu ?? 1420,
    routes: routes.toList()..sort(),
    dns: magicDns ? magicDnsServer : null,
  );
}

/// Returns a conflict description if [candidate] shares any claimed route
/// (excluding the common Magic DNS `/32`) with [existing], or null when disjoint.
String? findVpnRouteConflict(
  Iterable<AndroidVpnMember> existing,
  AndroidVpnMember candidate,
) {
  final candidateRoutes = candidate.claimedRoutes.where(
    (route) => route != _magicDnsRoute,
  );
  for (final member in existing) {
    if (member.network.networkName == candidate.network.networkName) continue;
    for (final existingRoute in member.claimedRoutes) {
      if (existingRoute == _magicDnsRoute) continue;
      for (final candidateRoute in candidateRoutes) {
        if (cidrsOverlap(existingRoute, candidateRoute)) {
          return 'Route $candidateRoute overlaps with $existingRoute '
              'owned by ${member.network.networkName}';
        }
      }
    }
  }
  return null;
}

/// Whether two CIDRs [a] and [b] share the same IP family and overlap.
bool cidrsOverlap(String a, String b) {
  final parsedA = _parseCidr(a);
  final parsedB = _parseCidr(b);
  if (parsedA == null || parsedB == null) return false;
  if (parsedA.address.type != parsedB.address.type) return false;
  final maxPrefix = parsedA.address.type == InternetAddressType.IPv4 ? 32 : 128;
  final int minPrefix = min(parsedA.prefix, parsedB.prefix);
  final shift = maxPrefix - minPrefix;
  return (_addressBits(parsedA.address) >> shift) ==
      (_addressBits(parsedB.address) >> shift);
}

/// The IPv4 or IPv6 network [cidr] designates, with its host bits cleared.
///
/// Bare IPv4 addresses default to `/24` and bare IPv6 addresses to `/64`.
/// Unparseable input comes back unchanged.
String ipNetworkCidr(String cidr) {
  final parsed = _parseCidr(cidr);
  if (parsed == null) return cidr;
  final isV4 = parsed.address.type == InternetAddressType.IPv4;
  final maxPrefix = isV4 ? 32 : 128;
  final shift = maxPrefix - parsed.prefix;
  final network = (_addressBits(parsed.address) >> shift) << shift;
  return '${_bitsToAddress(network, isV4: isV4).address}/${parsed.prefix}';
}

/// The IPv4 network [cidr] designates, with its host bits cleared.
///
/// Android's `VpnService.Builder.addRoute` rejects a route whose address has
/// host bits outside its prefix ("Bad address"), so a configured
/// `10.126.126.2/24` is routed as `10.126.126.0/24`. An address without a
/// prefix is taken as that host's `/24`; input the network editor never
/// allowed comes back unchanged, for the platform to report.
String ipv4NetworkCidr(String cidr) {
  final parsed = _parseCidr(cidr);
  if (parsed == null || parsed.address.type != InternetAddressType.IPv4) {
    return cidr;
  }
  return ipNetworkCidr(cidr);
}

/// Extracts EasyTier's assigned virtual IPv4 and IPv6 CIDRs from `collect_network_infos` JSON.
({String? ipv4, String? ipv6}) parseAssignedAddresses(String infoJson) {
  try {
    final decoded = jsonDecode(infoJson);
    if (decoded is! Map<String, Object?>) return (ipv4: null, ipv6: null);
    final myNodeInfo = decoded['my_node_info'];
    if (myNodeInfo is! Map<String, Object?>) return (ipv4: null, ipv6: null);
    return (
      ipv4: _ipv4CidrFromInet(myNodeInfo['virtual_ipv4']),
      ipv6: _ipv6CidrFromInet(myNodeInfo['virtual_ipv6']),
    );
  } catch (_) {
    return (ipv4: null, ipv6: null);
  }
}

String? _ipv4CidrFromInet(Object? inet) {
  if (inet is String && inet.isNotEmpty) {
    return _ensureCidr(inet, defaultPrefix: 24);
  }
  if (inet case {
    'address': {'addr': final int addr},
    'network_length': final int len,
  } when len >= 0 && len <= 32) {
    final ip = [24, 16, 8, 0].map((shift) => (addr >> shift) & 0xff).join('.');
    return '$ip/$len';
  }
  return null;
}

String? _ipv6CidrFromInet(Object? inet) {
  if (inet is String && inet.isNotEmpty) {
    return _ensureCidr(inet, defaultPrefix: 64);
  }
  if (inet case {
    'address': {
      'part1': final int p1,
      'part2': final int p2,
      'part3': final int p3,
      'part4': final int p4,
    },
    'network_length': final int len,
  } when len >= 0 && len <= 128) {
    final bytes = Uint8List(16);
    final parts = [p1, p2, p3, p4];
    for (var i = 0; i < 4; i++) {
      final part = parts[i];
      bytes[i * 4] = (part >> 24) & 0xff;
      bytes[i * 4 + 1] = (part >> 16) & 0xff;
      bytes[i * 4 + 2] = (part >> 8) & 0xff;
      bytes[i * 4 + 3] = part & 0xff;
    }
    return '${InternetAddress.fromRawAddress(bytes).address}/$len';
  }
  return null;
}

String _bootstrapDhcpIpv4(String? dhcpIpv4Cidr) {
  if (dhcpIpv4Cidr == null || dhcpIpv4Cidr.isEmpty) return _defaultDhcpIpv4;
  final parsed = _parseCidr(dhcpIpv4Cidr);
  if (parsed == null ||
      parsed.address.type != InternetAddressType.IPv4 ||
      parsed.prefix > 30) {
    return _defaultDhcpIpv4;
  }
  final shift = 32 - parsed.prefix;
  final network = (_addressBits(parsed.address) >> shift) << shift;
  final firstHost = _bitsToAddress(network + BigInt.one, isV4: true);
  return '${firstHost.address}/${parsed.prefix}';
}

String _bootstrapDhcpIpv6(String? dhcpIpv6Cidr) {
  if (dhcpIpv6Cidr == null || dhcpIpv6Cidr.isEmpty) return _defaultDhcpIpv6;
  final parsed = _parseCidr(dhcpIpv6Cidr);
  if (parsed == null ||
      parsed.address.type != InternetAddressType.IPv6 ||
      parsed.prefix > 126) {
    return _defaultDhcpIpv6;
  }
  final shift = 128 - parsed.prefix;
  final network = (_addressBits(parsed.address) >> shift) << shift;
  final firstHost = _bitsToAddress(network + BigInt.one, isV4: false);
  return '${firstHost.address}/${parsed.prefix}';
}

String _ensureCidr(String address, {required int defaultPrefix}) =>
    address.contains('/') ? address : '$address/$defaultPrefix';

({InternetAddress address, int prefix})? _parseCidr(String cidr) {
  final parts = cidr.split('/');
  if (parts.length > 2) return null;
  final address = InternetAddress.tryParse(parts.first);
  if (address == null) return null;
  final isV4 = address.type == InternetAddressType.IPv4;
  final maxPrefix = isV4 ? 32 : 128;
  final prefix = parts.length > 1 ? int.tryParse(parts[1]) : (isV4 ? 24 : 64);
  if (prefix == null || prefix < 0 || prefix > maxPrefix) return null;
  return (address: address, prefix: prefix);
}

BigInt _addressBits(InternetAddress address) => address.rawAddress.fold(
  BigInt.zero,
  (bits, byte) => (bits << 8) | BigInt.from(byte),
);

InternetAddress _bitsToAddress(BigInt bits, {required bool isV4}) {
  final length = isV4 ? 4 : 16;
  final bytes = Uint8List(length);
  for (var i = length - 1; i >= 0; i--) {
    bytes[i] = (bits & BigInt.from(0xff)).toInt();
    bits >>= 8;
  }
  return InternetAddress.fromRawAddress(bytes);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
