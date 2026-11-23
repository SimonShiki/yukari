/// Default root domain used by Magic DNS.
const defaultDnsDomain = 'et.net.';
const maxStaticDnsZones = 16;

/// Canonical comparison form for a DNS name.
String normalizeDnsName(String value) {
  var normalized = value.trim().toLowerCase();
  while (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

bool isDefaultDnsDomain(String value) =>
    normalizeDnsName(value) == normalizeDnsName(defaultDnsDomain);
