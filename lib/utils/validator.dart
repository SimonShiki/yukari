import 'dart:convert';
import 'dart:io';

import '../models/network.dart';
import 'line_formats.dart';

String nodeHost(Uri uri) => uri.host.isNotEmpty ? uri.host : uri.path;

// Form validators: each returns an error message, or null when the input is
// valid. Validators of optional values accept empty input.

String? validateNetworkName(String value, Iterable<String> takenNames) {
  final name = value.trim();
  if (name.isEmpty) return 'Network name cannot be empty';
  if (takenNames.contains(name)) return 'Network name already exists';
  return null;
}

String? validateHostname(String value) =>
    value.trim().length > 32 ? 'Hostname cannot exceed 32 characters' : null;

String? validateCidr(String value, InternetAddressType type) {
  if (value.isEmpty) return null;
  final parts = value.split('/');
  final address = parts.length == 2 ? InternetAddress.tryParse(parts[0]) : null;
  final prefix = parts.length == 2 ? int.tryParse(parts[1]) : null;
  final maxPrefix = type == InternetAddressType.IPv4 ? 32 : 128;
  if (address?.type == type && prefix != null && prefix >= 0 && prefix <= maxPrefix) {
    return null;
  }
  return type == InternetAddressType.IPv4
      ? 'Must be an IPv4 CIDR, e.g. 10.144.144.1/24'
      : 'Must be an IPv6 CIDR, e.g. fd00::1/64';
}

String? validateIntRange(String value, String label, int min, int max) {
  final number = int.tryParse(value.trim());
  if (number == null || number < min || number > max) {
    return '$label must be a number between $min and $max';
  }
  return null;
}

String? validatePort(String value) => validateIntRange(value, 'Port', 1, 65535);

final _hostnamePattern = RegExp(r'^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*\.?$');

/// An IP address or a DNS name.
String? validateHost(String value) {
  final host = value.trim();
  if (host.isEmpty) return 'Host cannot be empty';
  if (InternetAddress.tryParse(host) == null && !_hostnamePattern.hasMatch(host)) {
    return 'Must be a valid IP address or hostname';
  }
  return null;
}

/// A DNS domain such as `et.net.`.
String? validateDnsZone(String value) => _hostnamePattern.hasMatch(value.trim())
    ? null
    : 'Must be a domain, e.g. et.net.';

/// A peer address without port, e.g. `example.com` or `wss://example.com/path`.
String? validateNodeUrl(String value) {
  final url = Uri.tryParse(value.trim());
  if (url == null ||
      url.hasPort ||
      url.hasQuery ||
      url.hasFragment ||
      (url.hasScheme && url.host.isEmpty)) {
    return 'Must be an address without port, query or fragment';
  }
  return validateHost(nodeHost(url));
}

String? validateSocks5Proxy(String value) {
  if (value.isEmpty) return null;
  final url = Uri.tryParse(value);
  if (url == null ||
      url.scheme != 'socks5' ||
      validateHost(url.host) != null ||
      !url.hasPort ||
      validatePort('${url.port}') != null) {
    return 'Must look like socks5://host:port';
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
    return 'Invalid STUN server: $value';
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
    ? 'Invalid IP address: $value'
    : null;

/// An IPv4 network such as `10.0.0.0/24`, without host bits.
String? validateIpv4Network(String value) {
  final parts = value.split('/');
  final address = parts.length == 2 ? InternetAddress.tryParse(parts[0]) : null;
  final prefix = parts.length == 2 ? int.tryParse(parts[1]) : null;
  if (address?.type == InternetAddressType.IPv4 &&
      prefix != null &&
      prefix >= 0 &&
      prefix <= 32) {
    final bits = address!.rawAddress.fold(0, (bits, byte) => bits << 8 | byte);
    if (bits & ((1 << (32 - prefix)) - 1) == 0) return null;
  }
  return 'Invalid IPv4 network: $value';
}

/// `cidr` or `cidr->mapped_cidr` of the same size.
String? validateProxyNetwork(String value) {
  final proxy = parseProxyNetwork(value);
  final mapped = proxy.mappedCidr;
  return validateIpv4Network(proxy.cidr) ??
      (mapped == null ? null : validateIpv4Network(mapped)) ??
      (mapped == null || mapped.split('/')[1] == proxy.cidr.split('/')[1]
          ? null
          : 'Mapped network must have the same prefix: $value');
}

/// An IP address with port, e.g. `0.0.0.0:22022` or `[::]:22022`.
String? validateSocketAddress(String value) {
  final match = RegExp(r'^\[([^\]]+)\]:(\d+)$|^([^:\[\]]+):(\d+)$')
      .firstMatch(value.trim());
  final address = InternetAddress.tryParse(match?[1] ?? match?[3] ?? '');
  if (address == null ||
      (address.type == InternetAddressType.IPv6) != (match![1] != null) ||
      validatePort(match[2] ?? match[4]!) != null) {
    return 'Must be an IP address with port, e.g. 0.0.0.0:22022';
  }
  return null;
}

/// `proto://bind_address/destination_address`.
String? validatePortForward(String value) {
  final forward = parsePortForward(value);
  if (forward == null ||
      validateSocketAddress(forward.bindAddress) != null ||
      validateSocketAddress(forward.destinationAddress) != null) {
    return 'Invalid port forward: $value';
  }
  return null;
}

/// A port such as `80`, or a range such as `8000-9000`.
String? validatePortRange(String value) {
  final ports = value.split('-').map(int.tryParse).toList();
  if (ports.length > 2 ||
      ports.any((port) => port == null || port < 1 || port > 65535) ||
      ports.first! > ports.last!) {
    return 'Invalid port or range: $value';
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
  return 'Must be a base64-encoded 32-byte key';
}

/// First invalid value among those the network editor validates field by
/// field, or null. For networks that arrive whole, such as imports.
String? validateNetwork(Network network) {
  String? each(Iterable<String> values, String? Function(String) validate) =>
      values.map(validate).nonNulls.firstOrNull;
  final flags = network.flags;
  return validateHostname(network.hostname ?? '') ??
      validateCidr(network.ipv4 ?? '', InternetAddressType.IPv4) ??
      validateCidr(network.ipv6 ?? '', InternetAddressType.IPv6) ??
      validateSocks5Proxy(network.socks5Proxy?.toString() ?? '') ??
      validateIntRange('${flags.mtu}', 'MTU', 576, 65535) ??
      validateIntRange('${flags.multiThreadCount}', 'Thread count', 1, 256) ??
      validateDnsZone(flags.dnsZone) ??
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
