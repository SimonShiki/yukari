part of 'magic_dns.dart';

/// The configuration a user has to write by hand, for platforms where the app
/// cannot set the system DNS, and for a user whose elevation prompt failed.
extension MagicDnsManual on MagicDnsSystem {
  /// The commands that set [zone]'s DNS up by hand.
  ///
  /// [name] is the device's Magic DNS name when it is known; without it the
  /// command shows a placeholder, because EasyTier then falls back to the
  /// device's own hostname.
  List<String> manualCommands({
    required String zone,
    required String interfaceName,
    String? name,
  }) {
    if (!supported) return const [];
    // Android's redirect belongs to the root service, which installs it by
    // itself: the app has no command to offer.
    if (platform == MagicDnsPlatform.android) return const [];
    final base = magicDnsZoneBase(zone);
    if (automatic) {
      return [
        'nslookup ${name ?? '<hostname>.$base'} $magicDnsServer',
        'ipconfig /all',
      ];
    }
    final tun = interfaceName.isEmpty ? '<easytier-tun>' : interfaceName;
    return [
      'sudo resolvectl dns $tun $magicDnsServer',
      'sudo resolvectl domain $tun ~$base',
    ];
  }

  /// The lines to add to `/etc/resolv.conf` when systemd-resolved is absent.
  List<String> resolvConfLines({required String zone}) => [
    'nameserver $magicDnsServer',
    'search ${magicDnsZoneBase(zone)}',
  ];
}
