import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/models/network_flags.dart';

import '../utils/validator.dart';
import 'share_document.dart';

/// The zone a network runs Magic DNS under until the user changes it.
final String _defaultDnsZone = NetworkFlags().dnsZone;

/// The non-essential config of a shared network: how it runs, not who it is.
///
/// Device identity ([NetworkFlags.hostname], [NetworkFlags.deviceName]) stays
/// local — it names the sender's own device, and sharing it would give two
/// devices one Magic DNS name. Secure mode stays local too, as its peer
/// authentication needs a key pair the receiver must generate itself.
final class SharedConfigs {
  const SharedConfigs({
    this.noTun = false,
    this.acceptDns = false,
    this.dnsZone,
  });

  /// Whether the network runs without the TUN device.
  final bool noTun;

  /// Whether the network answers Magic DNS queries; never set together with
  /// [noTun], which has no interface to answer on.
  final bool acceptDns;

  /// The Magic DNS zone, when the network answers it and it differs from the
  /// default; a share may carry one anyway, and an import keeps it.
  final String? dnsZone;

  /// Whether these configs say nothing the import defaults already do.
  bool get isEmpty => !noTun && !acceptDns && dnsZone == null;

  Map<String, Object?> toJson() => {
    if (noTun) 'noTun': noTun,
    if (acceptDns) 'acceptDns': acceptDns,
    if (dnsZone != null) 'dnsZone': dnsZone,
  };
}

/// The configs [network] differs from a fresh network in, or null when it
/// differs in nothing worth sharing.
SharedConfigs? configsOf(Network network) {
  final flags = network.flags;
  // The editor never sets both: Magic DNS has no interface to answer on
  // without the TUN device.
  final acceptDns = flags.acceptDns && !flags.noTun;
  final configs = SharedConfigs(
    noTun: flags.noTun,
    acceptDns: acceptDns,
    // A zone nobody answers on says nothing about how the network runs.
    dnsZone: acceptDns ? _zoneToShare(flags.dnsZone) : null,
  );
  return configs.isEmpty ? null : configs;
}

/// The configs a share document carries in [value], or null when it carries
/// none.
///
/// A share arrives from a QR code of unknown origin, so every field is checked
/// and a bad one throws a [FormatException] instead of being half accepted.
SharedConfigs? configsFromJson(Object? value) {
  if (value == null) return null;
  if (value is! Map<String, Object?>) {
    throw const FormatException('Share configs are not an object');
  }
  final noTun = _flag(value['noTun'], 'noTun');
  final acceptDns = _flag(value['acceptDns'], 'acceptDns');
  if (noTun && acceptDns) {
    throw const FormatException('Share configs run both without a TUN and DNS');
  }
  return SharedConfigs(
    noTun: noTun,
    acceptDns: acceptDns,
    dnsZone: _zone(value['dnsZone']),
  );
}

/// Writes [configs] onto [network], leaving everything else at its default.
void applyConfigs(Network network, SharedConfigs configs) {
  network.flags
    ..noTun = configs.noTun
    ..acceptDns = configs.acceptDns;
  if (configs.dnsZone case final zone?) network.flags.dnsZone = zone;
}

/// The Magic DNS zone [zone] travels as, or null when it is the default or one
/// the receiver would refuse.
String? _zoneToShare(String zone) {
  final text = zone.trim();
  if (text == _defaultDnsZone || !_shareableZone(text)) return null;
  return text;
}

/// Whether [zone] can travel as a Magic DNS zone: a zone the network editor
/// accepts, written as a host that survives the wire.
bool _shareableZone(String zone) =>
    isValidDnsZoneText(zone) && shareableHost(zone);

bool _flag(Object? value, String field) {
  if (value == null) return false;
  if (value is! bool) {
    throw FormatException('Share config $field is not a boolean');
  }
  return value;
}

String? _zone(Object? value) {
  if (value == null) return null;
  // A zone is compared as written, so trimming it would silently redirect
  // Magic DNS to another domain.
  if (value is! String || value != value.trim() || !_shareableZone(value)) {
    throw const FormatException('Share config DNS zone is invalid');
  }
  return value;
}
