part of 'magic_dns.dart';

/// A zone as a DNS name: dot-separated labels of letters, digits and hyphens,
/// neither starting nor ending with a hyphen.
final _zoneName = RegExp(
  r'^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*$',
);

/// Whether [flags] ask for Magic DNS, which answers on the tunnel's own TUN
/// device and is therefore off in a network that has none.
bool magicDnsRequested(NetworkFlags flags) => flags.acceptDns && !flags.noTun;

/// [zone] without its trailing dot, as DNS tools spell it.
String magicDnsZoneBase(String zone) {
  final trimmed = zone.trim();
  return trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

/// The Magic DNS name of [host] under [zone], such as `laptop.et.net`.
String magicDnsNameOf({required String host, required String zone}) =>
    '$host.${magicDnsZoneBase(zone)}';

/// [zone]'s labels as the query name they become on the wire, spelled the way
/// `iptables -m string` reads them: `|02|et|03|net|00|` for `et.net.`.
///
/// The trailing zero is the root label, which is what keeps the match inside
/// the zone: `host.et.net.evil.com` does not contain these bytes.
///
/// Null when [zone] is not a plain DNS name, so an unusable zone never
/// reaches a rule.
String? magicDnsZoneHex(String zone) {
  final base = magicDnsZoneBase(zone);
  if (!_zoneName.hasMatch(base)) return null;
  final pattern = StringBuffer();
  for (final label in base.split('.')) {
    if (label.length > 63) return null;
    pattern.write('|${label.length.toRadixString(16).padLeft(2, '0')}|$label');
  }
  return '$pattern|00|';
}
