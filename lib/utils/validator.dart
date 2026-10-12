import 'dart:convert';
import 'dart:io';

import '../models/network.dart';

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

/// One `host[:port]` per line.
String? validateStunServers(String value) {
  for (final line in value.split('\n').map((line) => line.trim())) {
    if (line.isEmpty) continue;
    final url = Uri.tryParse('stun://$line');
    if (url == null ||
        url.path.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        url.userInfo.isNotEmpty ||
        validateHost(url.host) != null ||
        (url.hasPort && validatePort('${url.port}') != null)) {
      return 'Invalid STUN server: $line';
    }
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
String? validateNetwork(Network network) =>
    validateHostname(network.hostname ?? '') ??
    validateCidr(network.ipv4 ?? '', InternetAddressType.IPv4) ??
    validateCidr(network.ipv6 ?? '', InternetAddressType.IPv6) ??
    validateSocks5Proxy(network.socks5Proxy?.toString() ?? '') ??
    validateIntRange('${network.flags.mtu}', 'MTU', 576, 65535) ??
    validateStunServers(network.stunServers.join('\n')) ??
    validatePrivateKey(network.secureMode?.localPrivateKey ?? '');
