import 'package:material_ui/material_ui.dart';

import '../../models/node.dart';
import '../../models/peer.dart';

enum PeerTagTone { neutral, positive, caution }

/// A labeled fact about a peer, explained further by [description].
class PeerTag {
  const PeerTag(this.icon, this.label, this.description, [this.tone]);

  final IconData icon;
  final String label;
  final String description;
  final PeerTagTone? tone;
}

class PeerCardData {
  const PeerCardData({
    required this.id,
    required this.hostname,
    required this.latencyMs,
    required this.protocols,
    required this.connectionStatus,
    this.virtualIpv4,
    this.tags = const [],
    this.isSelf = false,
    this.onTap,
  });

  final String id;
  final String hostname;
  final int latencyMs;
  final List<String> protocols;
  final String connectionStatus;
  final String? virtualIpv4;
  final List<PeerTag> tags;

  /// Whether this is the local node rather than a remote peer.
  final bool isSelf;
  final VoidCallback? onTap;

  factory PeerCardData.fromPeer(Peer peer, {VoidCallback? onTap}) {
    return PeerCardData(
      id: peer.id,
      hostname: peer.hostname,
      latencyMs: peer.latency ~/ 1000,
      protocols: peer.protocols.map<String>(_formatProtocol).toList(),
      connectionStatus: _formatConnectionType(peer.connectionType),
      virtualIpv4: peer.virtualIpv4,
      tags: [
        ?_identityTag(peer.identityType),
        ?_securityTag(peer.secureAuthLevel),
      ],
      onTap: onTap,
    );
  }

  /// The local node, whose connection details do not apply.
  factory PeerCardData.fromSelf(Peer self) => PeerCardData(
    id: self.id,
    hostname: self.hostname,
    latencyMs: 0,
    protocols: const [],
    connectionStatus: 'Local',
    virtualIpv4: self.virtualIpv4,
    isSelf: true,
  );

  // Admins, which hold the network secret, are the usual case.
  static PeerTag? _identityTag(IdentityType type) => switch (type) {
    IdentityType.admin => null,
    IdentityType.credential => const PeerTag(
      Icons.key_rounded,
      'Credential',
      'Joined with a temporary credential instead of the network secret.',
    ),
    IdentityType.sharedNode => const PeerTag(
      Icons.public_rounded,
      'Shared node',
      'A public node that relays traffic. It is not a member of this network.',
    ),
  };

  // Without secure mode there is no handshake to report on.
  static PeerTag? _securityTag(SecureAuthLevel level) => switch (level) {
    SecureAuthLevel.none => null,
    SecureAuthLevel.encryptedUnauthenciated => const PeerTag(
      Icons.lock_open_rounded,
      'Unverified',
      "Traffic is encrypted, but this peer's identity is not verified.",
      PeerTagTone.caution,
    ),
    SecureAuthLevel.peerVerified => const PeerTag(
      Icons.lock_rounded,
      'Key verified',
      "Traffic is encrypted, and this peer's public key is trusted.",
      PeerTagTone.positive,
    ),
    SecureAuthLevel.networkSecretConfirmed => const PeerTag(
      Icons.verified_user_rounded,
      'Secret verified',
      'Traffic is encrypted, and this peer proved it knows the network secret.',
      PeerTagTone.positive,
    ),
  };

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

  /// Highlights good and poor latency with color roles, not blends.
  Color getLatencyColor(ColorScheme colors) {
    if (latencyMs < 100) return colors.tertiary;
    if (latencyMs < 300) return colors.onSurfaceVariant;
    return colors.error;
  }
}
