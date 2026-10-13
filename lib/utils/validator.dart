import 'dart:convert';
import 'dart:io';

import '../models/network.dart';
import '../models/node.dart';
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

/// A DNS domain such as `et.net.`.
String? validateDnsZone(String value) =>
    _hostnamePattern.hasMatch(value.trim()) ? null : l10n.value.validationDns;

/// A peer address without port, e.g. `example.com` or `wss://example.com/path`.
String? validateNodeUrl(String value) {
  final url = Uri.tryParse(value.trim());
  if (url == null ||
      url.hasPort ||
      url.hasQuery ||
      url.hasFragment ||
      (url.hasScheme && url.host.isEmpty)) {
    return l10n.value.validationNodeUrl;
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
  return l10n.value.validationIpv4Network(value);
}

/// `cidr` or `cidr->mapped_cidr` of the same size.
String? validateProxyNetwork(String value) {
  final proxy = parseProxyNetwork(value);
  final mapped = proxy.mappedCidr;
  return validateIpv4Network(proxy.cidr) ??
      (mapped == null ? null : validateIpv4Network(mapped)) ??
      (mapped == null || mapped.split('/')[1] == proxy.cidr.split('/')[1]
          ? null
          : l10n.value.validationMappedNetwork(value));
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
      validateIntRange(
        '${flags.multiThreadCount}',
        l10n.value.advancedThreadCountName,
        1,
        256,
      ) ??
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
