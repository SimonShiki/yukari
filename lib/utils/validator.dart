import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/network_components.dart';
import 'package:yukari_core/models/node.dart';
import 'package:yukari_core/utils/dns_name.dart';

import '../signals/locale.dart';
import 'line_formats.dart';

// Form validators: each returns an error message, or null when the input is
// valid. Validators of optional values accept empty input.

String? validateNetworkName(String value, Iterable<String> takenNames) {
  final name = value.trim();
  if (name.isEmpty) return l10n.value.validationNetworkEmpty;
  if (takenNames.contains(name)) return l10n.value.validationNetworkExists;
  return null;
}

String? validateHostname(String value) =>
    value.trim().length > 32 ? l10n.value.validationHostnameLength : null;

String? validateCidr(String value, InternetAddressType type) {
  if (value.isEmpty) return null;
  final parts = value.split('/');
  final address = parts.length == 2 ? InternetAddress.tryParse(parts[0]) : null;
  final prefix = parts.length == 2 ? int.tryParse(parts[1]) : null;
  final maxPrefix = type == InternetAddressType.IPv4 ? 32 : 128;
  if (address?.type == type &&
      prefix != null &&
      prefix >= 0 &&
      prefix <= maxPrefix) {
    return null;
  }
  return type == InternetAddressType.IPv4
      ? l10n.value.validationIpv4Cidr
      : l10n.value.validationIpv6Cidr;
}

/// A DHCP IPv4 subnet must be a network address with at least two usable
/// host addresses, as required by EasyTier's DHCP allocator.
String? validateDhcpIpv4Cidr(String value) {
  if (value.isEmpty) return null;
  final prefix = _ipv4NetworkPrefix(value);
  if (prefix == null) return l10n.value.validationIpv4Network(value);
  return prefix <= 30 ? null : l10n.value.validationDhcpIpv4Cidr;
}

/// An IPv6 network such as `fd00::/64`, without host bits.
String? validateIpv6Network(String value) =>
    _ipv6NetworkPrefix(value) != null
    ? null
    : l10n.value.validationIpv6Network(value);

int? _ipv6NetworkPrefix(String value) {
  final parts = value.split('/');
  final address = parts.length == 2 ? InternetAddress.tryParse(parts[0]) : null;
  final prefix = parts.length == 2 ? int.tryParse(parts[1]) : null;
  if (address?.type == InternetAddressType.IPv6 &&
      prefix != null &&
      prefix >= 0 &&
      prefix <= 128) {
    final bits = address!.rawAddress.fold(
      BigInt.zero,
      (acc, byte) => (acc << 8) | BigInt.from(byte),
    );
    final shift = 128 - prefix;
    if ((bits >> shift) << shift == bits) return prefix;
  }
  return null;
}

/// A DHCPv6 subnet must be an IPv6 network address with prefix `/0` to `/126`.
String? validateDhcpIpv6Cidr(String value) {
  if (value.isEmpty) return null;
  final prefix = _ipv6NetworkPrefix(value);
  if (prefix == null) return l10n.value.validationIpv6Network(value);
  return prefix <= 126 ? null : l10n.value.validationDhcpIpv6Cidr;
}

String? validateIntRange(String value, String label, int min, int max) {
  final number = int.tryParse(value.trim());
  if (number == null || number < min || number > max) {
    return l10n.value.validationRange(label, min.toString(), max.toString());
  }
  return null;
}

String? validatePort(String value) =>
    validateIntRange(value, l10n.value.networkPort, 1, 65535);

final _hostnamePattern = RegExp(
  r'^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*\.?$',
);

/// An IP address or a DNS name.
String? validateHost(String value) {
  final host = value.trim();
  if (host.isEmpty) return l10n.value.validationHostEmpty;
  if (InternetAddress.tryParse(host) == null &&
      !_hostnamePattern.hasMatch(host)) {
    return l10n.value.validationHost;
  }
  return null;
}

/// Whether [value] is a DNS zone such as `et.net.`: dotted labels that each
/// start and end with a letter or digit, and an optional trailing dot.
bool isValidDnsZoneText(String value) {
  final text = value.trim();
  final name = normalizeDnsName(text);
  if (name.isEmpty || name.length > 253 || !_hostnamePattern.hasMatch(text)) {
    return false;
  }
  return name.split('.').every((label) => label.length <= 63);
}

/// A DNS domain such as `et.net.`.
String? validateDnsZone(String value) =>
    isValidDnsZoneText(value) ? null : l10n.value.validationDns;

/// A static DNS zone origin: non-empty, valid non-root DNS name, unique among
/// [existingOrigins].
String? validateDnsOrigin(
  String value, {
  Iterable<String> existingOrigins = const [],
}) {
  final origin = value.trim();
  if (origin.isEmpty) return l10n.value.validationDnsOriginEmpty;
  if (!isValidDnsZoneText(origin)) {
    return l10n.value.validationDns;
  }
  if (existingOrigins.length >= maxStaticDnsZones) {
    return l10n.value.validationDnsZoneLimit;
  }
  final normalized = normalizeDnsName(origin);
  if (existingOrigins.any((existing) => normalizeDnsName(existing) == normalized)) {
    return l10n.value.validationDnsOriginExists;
  }
  return null;
}

final _dnsOwnerLabelPattern = RegExp(
  r'^[A-Za-z0-9_]([A-Za-z0-9_-]*[A-Za-z0-9_])?$',
);

/// A DNS record owner name (`@`, `*`, relative owner labels, or FQDN).
String? validateDnsRecordName(String value) {
  final name = value.trim();
  if (name.isEmpty) return l10n.value.validationDnsRecordNameEmpty;
  if (name == '@' || name == '*') return null;
  if (name == '*.') return l10n.value.validationDnsRecordName;
  final trimmed = name.endsWith('.')
      ? name.substring(0, name.length - 1)
      : name;
  if (trimmed.isEmpty) return l10n.value.validationDnsRecordName;
  final labels = trimmed.split('.');
  for (var i = 0; i < labels.length; i++) {
    final label = labels[i];
    if (label.isEmpty || label.length > 63) {
      return l10n.value.validationDnsRecordName;
    }
    if (i == 0 && label == '*') continue;
    if (!_dnsOwnerLabelPattern.hasMatch(label)) {
      return l10n.value.validationDnsRecordName;
    }
  }
  if (trimmed.length > 253) return l10n.value.validationDnsRecordName;
  return null;
}

/// Validates a static DNS record's presentation RDATA value for [type].
String? validateDnsRecordValue(String value, DnsRecordType type) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return l10n.value.validationDnsRecordValueEmpty;
  if (type == DnsRecordType.a) {
    final parsed = InternetAddress.tryParse(trimmed);
    if (parsed?.type != InternetAddressType.IPv4) {
      return l10n.value.validationDnsRecordIpv4;
    }
  } else if (type == DnsRecordType.aaaa) {
    final parsed = InternetAddress.tryParse(trimmed);
    if (parsed?.type != InternetAddressType.IPv6) {
      return l10n.value.validationDnsRecordIpv6;
    }
  } else if (!_validDnsRdata(trimmed, type)) {
    return l10n.value.validationDns;
  }
  return null;
}

bool _validDnsRdata(String value, DnsRecordType type) {
  bool dnsName(String text) => text == '.' || isValidDnsZoneText(text);
  bool number(String text, [int max = 4294967295]) {
    final parsed = int.tryParse(text);
    return parsed != null && parsed >= 0 && parsed <= max;
  }

  bool txtStrings() {
    final pattern = RegExp(r'"((?:[^"\\]|\\.)*)"');
    if (!RegExp(r'^(?:"(?:[^"\\]|\\.)*"\s*)+$').hasMatch(value)) {
      return false;
    }
    return pattern
        .allMatches(value)
        .every((match) => utf8.encode(match.group(1)!).length <= 255);
  }

  final fields = value.split(RegExp(r'\s+'));
  return switch (type) {
    DnsRecordType.aname ||
    DnsRecordType.cname ||
    DnsRecordType.ns ||
    DnsRecordType.ptr => dnsName(value),
    DnsRecordType.mx =>
      fields.length == 2 && number(fields[0], 65535) && dnsName(fields[1]),
    DnsRecordType.srv =>
      fields.length == 4 &&
          fields.take(3).every((field) => number(field, 65535)) &&
          dnsName(fields[3]),
    DnsRecordType.txt => txtStrings(),
    DnsRecordType.soa =>
      fields.length == 7 &&
          dnsName(fields[0]) &&
          dnsName(fields[1]) &&
          fields.skip(2).every(number),
    _ => true,
  };
}

/// Validates an optional DNS TTL value (`0` to `2147483647` seconds).
String? validateDnsTtl(String value) =>
    validateOptionalIntRange(value, l10n.value.advancedDnsTtl, 0, 2147483647);

/// A complete peer connection URL, including an optional path and query.
String? validateNodeUrl(String value) {
  final trimmed = value.trim();
  final url = Uri.tryParse(trimmed);
  if (url == null || !isValidNodeUrl(trimmed, url)) {
    return l10n.value.validationNodeUrl;
  }
  return validateHost(url.host);
}

String? validateSocks5Proxy(String value) {
  if (value.isEmpty) return null;
  final url = Uri.tryParse(value);
  if (url == null ||
      url.scheme != 'socks5' ||
      validateHost(url.host) != null ||
      !url.hasPort ||
      validatePort('${url.port}') != null) {
    return l10n.value.validationSocks;
  }
  return null;
}

/// Every non-empty line passes [validateLine].
String? validateLines(
  String value,
  String? Function(String line) validateLine,
) {
  for (final line in splitLines(value)) {
    if (validateLine(line) case final error?) return error;
  }
  return null;
}

/// A `host[:port]` STUN server.
String? validateStunServer(String value) {
  final url = Uri.tryParse('stun://$value');
  if (url == null ||
      url.path.isNotEmpty ||
      url.hasQuery ||
      url.hasFragment ||
      url.userInfo.isNotEmpty ||
      validateHost(url.host) != null ||
      (url.hasPort && validatePort('${url.port}') != null)) {
    return l10n.value.validationStun(value);
  }
  return null;
}

String? validateOptionalIntRange(
  String value,
  String label,
  int min,
  int max,
) => value.trim().isEmpty ? null : validateIntRange(value, label, min, max);

String? validateIp(String value) => InternetAddress.tryParse(value) == null
    ? l10n.value.validationIp(value)
    : null;

/// An IPv4 network such as `10.0.0.0/24`, without host bits.
String? validateIpv4Network(String value) =>
    _ipv4NetworkPrefix(value) != null
    ? null
    : l10n.value.validationIpv4Network(value);

int? _ipv4NetworkPrefix(String value) {
  final parts = value.split('/');
  final address = parts.length == 2 ? InternetAddress.tryParse(parts[0]) : null;
  final prefix = parts.length == 2 ? int.tryParse(parts[1]) : null;
  if (address?.type == InternetAddressType.IPv4 &&
      prefix != null &&
      prefix >= 0 &&
      prefix <= 32) {
    final bits = ByteData.sublistView(address!.rawAddress).getUint32(0);
    if (bits & ((1 << (32 - prefix)) - 1) == 0) return prefix;
  }
  return null;
}

/// `cidr` or `cidr->mapped_cidr` of the same size.
String? validateProxyNetwork(String value) {
  final proxy = parseProxyNetwork(value);
  final mapped = proxy.mappedCidr;
  final cidrPrefix = _ipv4NetworkPrefix(proxy.cidr);
  if (cidrPrefix == null) return l10n.value.validationIpv4Network(proxy.cidr);
  if (mapped == null) return null;
  final mappedPrefix = _ipv4NetworkPrefix(mapped);
  if (mappedPrefix == null) return l10n.value.validationIpv4Network(mapped);
  return mappedPrefix == cidrPrefix
      ? null
      : l10n.value.validationMappedNetwork(value);
}

/// An IP address with port, e.g. `0.0.0.0:22022` or `[::]:22022`.
String? validateSocketAddress(String value) {
  final match = RegExp(r'^\[([^\]]+)\]:(\d+)$|^([^:\[\]]+):(\d+)$')
      .firstMatch(value.trim());
  final address = InternetAddress.tryParse(match?[1] ?? match?[3] ?? '');
  if (address == null ||
      (address.type == InternetAddressType.IPv6) != (match![1] != null) ||
      validatePort(match[2] ?? match[4]!) != null) {
    return l10n.value.validationSocket;
  }
  return null;
}

/// `proto://bind_address/destination_address`.
String? validatePortForward(String value) {
  final forward = parsePortForward(value);
  if (forward == null ||
      validateSocketAddress(forward.bindAddress) != null ||
      validateSocketAddress(forward.destinationAddress) != null) {
    return l10n.value.validationPortForward(value);
  }
  return null;
}

/// A port such as `80`, or a range such as `8000-9000`.
String? validatePortRange(String value) {
  final ports = value.split('-').map(int.tryParse).toList();
  if (ports.length > 2 ||
      ports.any((port) => port == null || port < 1 || port > 65535) ||
      ports.first! > ports.last!) {
    return l10n.value.validationPortRange(value);
  }
  return null;
}

String? validatePrivateKey(String value) {
  if (value.isEmpty) return null;
  try {
    if (base64.decode(value).length == 32) return null;
  } on FormatException {
    // Fall through to the error below.
  }
  return l10n.value.validationPrivateKey;
}

String? validateDnsZones(Iterable<DnsZone> zones) {
  if (zones.length > maxStaticDnsZones) {
    return l10n.value.validationDnsZoneLimit;
  }
  final seen = <String>[];
  for (final zone in zones) {
    final originError = validateDnsOrigin(zone.origin, existingOrigins: seen);
    if (originError != null) return originError;
    seen.add(zone.origin);
    if (zone.ttl case final int ttl) {
      final ttlError = validateDnsTtl('$ttl');
      if (ttlError != null) return ttlError;
    }
    for (final record in zone.records) {
      final nameError = validateDnsRecordName(record.name);
      if (nameError != null) return nameError;
      final valueError = validateDnsRecordValue(record.value, record.type);
      if (valueError != null) return valueError;
      if (record.ttl case final int ttl) {
        final ttlError = validateDnsTtl('$ttl');
        if (ttlError != null) return ttlError;
      }
    }
  }
  return null;
}

/// First invalid value among those the network editor validates field by
/// field, or null. Used for networks that arrive whole, such as imports.
String? validateNetwork(Network network) {
  String? each(Iterable<String> values, String? Function(String) validate) =>
      values.map(validate).nonNulls.firstOrNull;
  final flags = network.flags;
  return validateHostname(network.hostname ?? '') ??
      validateCidr(network.ipv4 ?? '', InternetAddressType.IPv4) ??
      validateDhcpIpv4Cidr(network.dhcpIpv4Cidr ?? '') ??
      validateCidr(network.ipv6 ?? '', InternetAddressType.IPv6) ??
      validateDhcpIpv6Cidr(network.dhcpIpv6Cidr ?? '') ??
      validateSocks5Proxy(network.socks5Proxy?.toString() ?? '') ??
      validateIntRange('${flags.mtu}', 'MTU', 576, 65535) ??
      validateIntRange(
        '${flags.multiThreadCount}',
        l10n.value.advancedThreadCountName,
        1,
        256,
      ) ??
      validateDnsZone(network.effectiveDnsDomain) ??
      validateDnsZones(network.dns?.zones ?? const []) ??
      each(
        network.proxyNetworks.map(formatProxyNetwork),
        validateProxyNetwork,
      ) ??
      each(network.routes, validateIpv4Network) ??
      each(network.exitNodes, validateIp) ??
      each(network.portForwards.map(formatPortForward), validatePortForward) ??
      each([
        ...network.tcpWhitelist,
        ...network.udpWhitelist,
      ], validatePortRange) ??
      each([
        ...network.stunServers,
        ...network.tcpStunServers,
        ...network.stunServersV6,
      ], validateStunServer) ??
      validateCidr(
        network.ipv6PublicAddressPrefix ?? '',
        InternetAddressType.IPv6,
      ) ??
      (network.vpnPortal == null
          ? null
          : validateSocketAddress(network.vpnPortal!.wireguardListen)) ??
      validatePrivateKey(network.secureMode?.localPrivateKey ?? '');
}
