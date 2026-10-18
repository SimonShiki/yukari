import '../controllers/home_controller.dart' show TrafficSample;
import '../utils/byte_units.dart';

/// The tray context menu: a plain description the platform adapter turns into
/// a native menu, and the tests read without any plugin.
final class TrayMenu {
  const TrayMenu(this.entries);

  final List<TrayMenuEntry> entries;
}

/// One row of a [TrayMenu].
sealed class TrayMenuEntry {
  const TrayMenuEntry();
}

/// A divider between groups of rows.
final class TrayMenuSeparator extends TrayMenuEntry {
  const TrayMenuSeparator();
}

/// One row of the menu: a command, a section label, or a network to toggle.
///
/// Rows are flat on purpose. The network rows used to sit in a submenu, but no
/// platform's native menu reserves room for a submenu arrow next to a long
/// label and the arrow overlapped the text, so the list is a top-level section
/// instead.
final class TrayMenuItem extends TrayMenuEntry {
  const TrayMenuItem({
    required this.id,
    required this.label,
    this.checked,
    this.enabled = true,
    this.onSelected,
  });

  /// Stable across rebuilds, so the platform can update this row in place.
  final String id;
  final String label;

  /// Whether the row shows a check mark, or null when it is a plain action.
  final bool? checked;
  final bool enabled;
  final void Function()? onSelected;
}

/// Joins a network row's parts. A symbol, not translatable text: only the
/// peer count is built from localized words.
const String _separator = ' · ';

/// [name] with the connected-peer count, the node's own address and its live
/// traffic, in one line; just [name] when the network is not running.
///
/// [traffic] is not null only while the network runs, which is also when the
/// peer count and [address] are known.
String trayNetworkLabel(
  String name, {
  required String? peers,
  required String? address,
  required TrafficSample? traffic,
}) {
  if (traffic == null) return name;
  return [
    name,
    if (peers != null && peers.isNotEmpty) peers,
    if (address != null && address.isNotEmpty) address,
    formatTrafficRates(receive: traffic.receiveRate, send: traffic.sendRate),
  ].join(_separator);
}
