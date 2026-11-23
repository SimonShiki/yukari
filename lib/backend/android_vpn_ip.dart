import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:yukari_core/models/peer.dart';

const _defaultDhcpIpv4 = '10.126.126.1/24';
const _defaultDhcpIpv6 = 'fd6b:8c2d:91e4::1/64';

/// Whether two CIDRs [a] and [b] share an IP family and overlap.
bool cidrsOverlap(String a, String b) {
  final parsedA = parseCidr(a);
  final parsedB = parseCidr(b);
  if (parsedA == null || parsedB == null) return false;
  if (parsedA.address.type != parsedB.address.type) return false;
  final width = parsedA.address.type == InternetAddressType.IPv4 ? 32 : 128;
  final prefix = parsedA.prefix < parsedB.prefix
      ? parsedA.prefix
      : parsedB.prefix;
  final shift = width - prefix;
  return (addressBits(parsedA.address) >> shift) ==
      (addressBits(parsedB.address) >> shift);
}

/// The network [cidr] designates, with host bits cleared.
String ipNetworkCidr(String cidr) {
  final parsed = parseCidr(cidr);
  if (parsed == null) return cidr;
  final isV4 = parsed.address.type == InternetAddressType.IPv4;
  final width = isV4 ? 32 : 128;
  final shift = width - parsed.prefix;
  final network = (addressBits(parsed.address) >> shift) << shift;
  return '${bitsToAddress(network, isV4: isV4).address}/${parsed.prefix}';
}

/// Extracts EasyTier's assigned virtual addresses from its info JSON.
({String? ipv4, String? ipv6}) parseAssignedAddresses(String infoJson) {
  try {
    final decoded = jsonDecode(infoJson);
    if (decoded is! Map<String, Object?>) return (ipv4: null, ipv6: null);
    final myNodeInfo = decoded['my_node_info'];
    if (myNodeInfo is! Map<String, Object?>) return (ipv4: null, ipv6: null);
    final ipv4 = Peer.ipv4CidrFromInet(myNodeInfo['virtual_ipv4']);
    final ipv6 = Peer.ipv6CidrFromInet(myNodeInfo['virtual_ipv6']);
    return (
      ipv4: ipv4 == null ? null : ensureCidr(ipv4, defaultPrefix: 24),
      ipv6: ipv6 == null ? null : ensureCidr(ipv6, defaultPrefix: 64),
    );
  } catch (_) {
    return (ipv4: null, ipv6: null);
  }
}

String bootstrapDhcpIpv4(String? cidr) => _bootstrapDhcpIp(
  cidr,
  type: InternetAddressType.IPv4,
  maxPrefix: 30,
  fallback: _defaultDhcpIpv4,
);

String bootstrapDhcpIpv6(String? cidr) => _bootstrapDhcpIp(
  cidr,
  type: InternetAddressType.IPv6,
  maxPrefix: 126,
  fallback: _defaultDhcpIpv6,
);

String _bootstrapDhcpIp(
  String? cidr, {
  required InternetAddressType type,
  required int maxPrefix,
  required String fallback,
}) {
  if (cidr == null || cidr.isEmpty) return fallback;
  final parsed = parseCidr(cidr);
  if (parsed == null ||
      parsed.address.type != type ||
      parsed.prefix > maxPrefix) {
    return fallback;
  }
  final width = type == InternetAddressType.IPv4 ? 32 : 128;
  final shift = width - parsed.prefix;
  final network = (addressBits(parsed.address) >> shift) << shift;
  final firstHost = bitsToAddress(
    network + BigInt.one,
    isV4: type == InternetAddressType.IPv4,
  );
  return '${firstHost.address}/${parsed.prefix}';
}

String ensureCidr(String address, {required int defaultPrefix}) =>
    address.contains('/') ? address : '$address/$defaultPrefix';

({InternetAddress address, int prefix})? parseCidr(String cidr) {
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

BigInt addressBits(InternetAddress address) => address.rawAddress.fold(
  BigInt.zero,
  (bits, byte) => (bits << 8) | BigInt.from(byte),
);

InternetAddress bitsToAddress(BigInt bits, {required bool isV4}) {
  final bytes = Uint8List(isV4 ? 4 : 16);
  for (var index = bytes.length - 1; index >= 0; index--) {
    bytes[index] = (bits & BigInt.from(0xff)).toInt();
    bits >>= 8;
  }
  return InternetAddress.fromRawAddress(bytes);
}
