import '../../l10n/l10n.dart';
import 'package:yukari_core/models/log_entry.dart';

/// Formats event summaries at the UI boundary, keeping journal models pure Dart.
String formatLogSummary(LogEntry entry, AppLocalizations l10n) {
  String text(Object? value) => LogEntry.text(value, none: l10n.logNone);
  String arg(int index) => text(entry.arg(index));
  String field(List<String> keys) => text(entry.path(keys));
  return switch (entry.kind) {
    'TunDeviceReady' => l10n.logTunDeviceReady(arg(0)),
    'TunDeviceError' => l10n.logTunDeviceError(arg(0)),
    'PeerAdded' => l10n.logPeerAdded(arg(0)),
    'PeerRemoved' => l10n.logPeerRemoved(arg(0)),
    'PeerConnAdded' => l10n.logPeerConnAdded(
      field(['peer_id']),
      field(['tunnel', 'remote_addr'])
    ),
    'PeerConnRemoved' => l10n.logPeerConnRemoved(
      field(['peer_id']),
      field(['tunnel', 'tunnel_type']),
      field(['tunnel', 'remote_addr']),
    ),
    'ListenerAdded' => l10n.logListenerAdded(arg(0)),
    'ListenerAddFailed' => l10n.logListenerAddFailed(arg(0), arg(1)),
    'ListenerAcceptFailed' => l10n.logListenerAcceptFailed(arg(0), arg(1)),
    'ListenerPortMappingEstablished' => l10n.logListenerPortMappingEstablished(
      field(['local_listener']),
      field(['mapped_listener']),
      field(['backend']),
    ),
    'Connecting' => l10n.logConnecting(arg(0)),
    'ConnectError' => l10n.logConnectError(arg(0), arg(1), arg(2)),
    'ConnectionAccepted' => l10n.logConnectionAccepted(arg(0), arg(1)),
    'ConnectionError' => l10n.logConnectionError(arg(0), arg(1), arg(2)),
    'VpnPortalStarted' => l10n.logVpnPortalStarted(arg(0)),
    'VpnPortalClientConnected' => l10n.logVpnPortalClientConnected(arg(1)),
    'VpnPortalClientDisconnected' => l10n.logVpnPortalClientDisconnected(
      arg(1),
    ),
    'DhcpIpv4Changed' => l10n.logDhcpIpv4Changed(arg(0), arg(1)),
    'DhcpIpv4Conflicted' => l10n.logDhcpIpv4Conflicted(arg(0)),
    'PublicIpv6Changed' => l10n.logPublicIpv6Changed(arg(0), arg(1)),
    'PublicIpv6RoutesUpdated' => l10n.logPublicIpv6RoutesUpdated(
      arg(0),
      arg(1),
    ),
    'ProxyCidrsUpdated' => l10n.logProxyCidrsUpdated(arg(0), arg(1)),
    'PortForwardAdded' => l10n.logPortForwardAdded,
    'ConfigPatched' => l10n.logConfigPatched,
    'CredentialChanged' => l10n.logCredentialChanged,
    'Unknown' => l10n.logUnknown,
    'UdpBroadcastRelayStartResult' =>
      entry.path(['error']) == null
          ? l10n.logUdpRelayStarted(field(['capture_backend']))
          : l10n.logUdpRelayFailed(field(['error'])),
    _ => entry.kind,
  };
}
