part of 'magic_dns.dart';

/// The platforms Yukari ships on, as far as the system DNS setup goes.
enum MagicDnsPlatform {
  /// The app points systemd-resolved at the EasyTier interface.
  linux,

  /// EasyTier writes the DNS servers of its own TUN interface itself.
  windows,

  /// The root service sends the zone's lookups into the EasyTier tunnel,
  /// because Android has no API that points its resolver at one zone.
  android,

  /// No system DNS setup in this process: Android's app mode leaves the server
  /// to its own VpnService (see `AndroidBackend`), and the root service there
  /// selects `android` itself.
  other,
}

/// The [MagicDnsPlatform] of the running system.
///
/// The Android service runs a Linux build, so it selects `android` itself;
/// the app process on Android configures nothing here.
MagicDnsPlatform _runningPlatform() {
  if (Platform.isLinux) return MagicDnsPlatform.linux;
  if (Platform.isWindows) return MagicDnsPlatform.windows;
  return MagicDnsPlatform.other;
}

/// Everything the Magic DNS helper shows.
///
/// [off] and [notRunning] are the network's state, added by the controller;
/// [MagicDnsSystem.probe] reports the others.
enum MagicDnsState {
  /// Magic DNS is off for this network.
  off,

  /// Magic DNS is on, but the network is not running.
  notRunning,

  /// This host cannot be configured from here: no systemd-resolved on Linux,
  /// no usable iptables on Android.
  unsupported,

  /// No EasyTier interface yet: the network is not running, or still starting.
  noInterface,

  /// The system DNS does not send the zone to the Magic DNS server.
  missing,

  /// The system DNS sends the zone to the Magic DNS server.
  configured,

  /// The last probe or elevated command failed; the error says why.
  failed,
}

/// One look at the system DNS, with the EasyTier interface found on the way.
typedef MagicDnsProbe = ({MagicDnsState state, String? interface});
