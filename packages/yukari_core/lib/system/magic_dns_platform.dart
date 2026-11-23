part of 'magic_dns.dart';

/// The platforms Yukari configures system DNS on.
enum MagicDnsPlatform {
  /// The Android root service sends the zone's lookups into the EasyTier tunnel,
  /// because Android has no API that points its resolver at one zone.
  android,

  /// No system DNS setup in this process: Windows and Linux are handled
  /// natively by EasyTier, and Android's app mode leaves the server to its
  /// own VpnService (see `AndroidBackend`).
  other,
}

/// The [MagicDnsPlatform] of the running system.
///
/// The Android root service runs a Linux build, so it selects `android` itself;
/// all other processes configure nothing here.
MagicDnsPlatform _runningPlatform() => MagicDnsPlatform.other;

/// The system DNS probe states reported by [MagicDnsSystem.probe].
enum MagicDnsState {
  /// This host cannot be configured from here (not the Android root service,
  /// invalid zone, or no usable iptables).
  unsupported,

  /// No EasyTier interface yet: the network is not running, or still starting.
  noInterface,

  /// The system DNS does not send the zone to the Magic DNS server.
  missing,

  /// The system DNS sends the zone to the Magic DNS server.
  configured,
}

/// One look at the system DNS, with the EasyTier interface found on the way.
typedef MagicDnsProbe = ({MagicDnsState state, String? interface});
