import '../models/network_components.dart';

// One-line text forms of list entries, as EasyTier's command line takes them.

/// The trimmed, non-empty lines of [text].
List<String> splitLines(String text) => [
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty) line.trim(),
];

/// `cidr`, or `cidr->mapped_cidr` for a remapped network.
String formatProxyNetwork(ProxyNetwork proxy) => proxy.mappedCidr == null
    ? proxy.cidr
    : '${proxy.cidr}->${proxy.mappedCidr}';

ProxyNetwork parseProxyNetwork(String line) {
  final parts = line.split('->').map((part) => part.trim()).toList();
  return ProxyNetwork(cidr: parts.first, mappedCidr: parts.elementAtOrNull(1));
}

/// `proto://bind_address/destination_address`.
String formatPortForward(PortForward forward) =>
    '${forward.protocol}://${forward.bindAddress}/${forward.destinationAddress}';

PortForward? parsePortForward(String line) {
  final match = RegExp(r'^(tcp|udp)://([^/]+)/([^/]+)$')
      .firstMatch(line.trim());
  return match == null
      ? null
      : PortForward(
          protocol: match[1]!,
          bindAddress: match[2]!,
          destinationAddress: match[3]!,
        );
}
