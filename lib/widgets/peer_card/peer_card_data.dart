import 'package:material_ui/material_ui.dart';

import '../../models/node.dart';
import '../../models/peer.dart';

class PeerCardData {
  const PeerCardData({
    required this.id,
    required this.hostname,
    required this.identityIcon,
    required this.latencyMs,
    required this.protocols,
    required this.connectionStatus,
    this.secureIcon,
    this.secureIconColor,
    this.onTap,
  });

  final String id;
  final String hostname;
  final IconData identityIcon;
  final IconData? secureIcon;
  final Color? secureIconColor;
  final int latencyMs;
  final List<String> protocols;
  final String connectionStatus;
  final VoidCallback? onTap;

  factory PeerCardData.fromPeer(Peer peer, {VoidCallback? onTap}) {
    return PeerCardData(
      id: peer.id,
      hostname: peer.hostname,
      identityIcon: _getIdentityIcon(peer.identityType),
      secureIcon: _getSecureIcon(peer.secureAuthLevel),
      secureIconColor: _getSecureIconColor(peer.secureAuthLevel),
      latencyMs: peer.latency ~/ 1000,
      protocols: peer.protocols.map<String>(_formatProtocol).toList(),
      connectionStatus: _formatConnectionType(peer.connectionType),
      onTap: onTap,
    );
  }

  static IconData _getIdentityIcon(IdentityType type) {
    return switch (type) {
      IdentityType.admin => Icons.admin_panel_settings_rounded,
      IdentityType.credential => Icons.key_rounded,
      IdentityType.sharedNode => Icons.share_rounded,
    };
  }

  static IconData? _getSecureIcon(SecureAuthLevel level) {
    return switch (level) {
      SecureAuthLevel.none => null,
      SecureAuthLevel.encryptedUnauthenciated => Icons.lock_outline_rounded,
      SecureAuthLevel.peerVerified => Icons.lock_rounded,
      SecureAuthLevel.networkSecretConfirmed => Icons.verified_user_rounded,
    };
  }

  static Color? _getSecureIconColor(SecureAuthLevel level) {
    return switch (level) {
      SecureAuthLevel.none => null,
      SecureAuthLevel.encryptedUnauthenciated => null,
      SecureAuthLevel.peerVerified => null,
      SecureAuthLevel.networkSecretConfirmed => null,
    };
  }

  static String _formatProtocol(NodeProtocol protocol) {
    return protocol.name.toUpperCase();
  }

  static String _formatConnectionType(PeerConnectionType type) {
    return switch (type) {
      PeerConnectionType.local => 'Local',
      PeerConnectionType.direct => 'P2P',
      PeerConnectionType.relay => 'Relay',
    };
  }

  Color getLatencyColor(ColorScheme colors) {
    if (latencyMs < 50) {
      return colors.tertiary;
    } else if (latencyMs < 150) {
      return colors.primary;
    } else if (latencyMs < 300) {
      return Color.lerp(colors.primary, colors.error, 0.5)!;
    } else {
      return colors.error;
    }
  }
}
