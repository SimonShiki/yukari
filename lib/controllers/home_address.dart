part of 'home_controller.dart';

/// What the address card shows: nothing before the first refresh, nothing
/// while STUN is still answering, a virtual address, the public address STUN
/// reported, or nothing at all.
enum AddressKind { initial, waiting, virtual, public, unavailable }

/// One virtual address the dashboard lists, with its Magic DNS host.
typedef HomeAddressEntry = ({String address, String? host, String network});

/// The virtual addresses of [running], in saved order.
List<HomeAddressEntry> homeAddressesOf(List<Instance> running) => [
  for (final instance in running)
    if (instance.myself?.virtualIpv4 case final String address)
      (
        address: address,
        host: _magicDnsHostOf(instance.network),
        network: instance.network.networkName,
      ),
];

/// The Magic DNS name of [network], when it asks for one: its configured
/// hostname under its DNS zone, without the zone's one trailing dot.
String? _magicDnsHostOf(Network network) {
  if (!network.flags.acceptDns) return null;
  final hostname = network.hostname ?? '';
  final zone = network.flags.dnsZone;
  if (hostname.isEmpty || zone.isEmpty) return null;
  final trimmed = zone.endsWith('.')
      ? zone.substring(0, zone.length - 1)
      : zone;
  return '$hostname.$trimmed';
}

/// Which address the card shows, from the first refresh and the STUN answer.
AddressKind addressKindOf(
  bool refreshed,
  List<HomeAddressEntry> addresses,
  NatProbe? probe,
) {
  if (!refreshed) return AddressKind.initial;
  if (addresses.isNotEmpty) return AddressKind.virtual;
  if (probe == null) return AddressKind.waiting;
  return probe.publicAddress == null
      ? AddressKind.unavailable
      : AddressKind.public;
}

/// The address the card shows: the first virtual one, else STUN's public one.
String? addressOf(List<HomeAddressEntry> addresses, NatProbe? probe) =>
    addresses.firstOrNull?.address ?? probe?.publicAddress;

/// `host · network` of the first address.
String addressSupportingOf(List<HomeAddressEntry> addresses) {
  final first = addresses.firstOrNull;
  if (first == null) return '';
  return [if (first.host != null) first.host!, first.network].join(' · ');
}

/// How many addresses follow the first.
int addressMoreCountOf(List<HomeAddressEntry> addresses) =>
    max(0, addresses.length - 1);

/// Every address as `address  host  network` lines, or null when the value
/// alone says everything there is to say.
String? addressTooltipOf(List<HomeAddressEntry> addresses) {
  if (addresses.isEmpty) return null;
  if (addresses.length == 1 && addresses.first.host == null) return null;
  return addresses
      .map(
        (entry) => [
          entry.address,
          if (entry.host != null) entry.host!,
          entry.network,
        ].join('  '),
      )
      .join('\n');
}
