import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
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

  factory PeerCardData.fromPeer(
    Peer peer,
    AppLocalizations l10n, {
    VoidCallback? onTap,
  }) {
    return PeerCardData(
      id: peer.id,
      hostname: peer.hostname,
      latencyMs: peer.latency ~/ 1000,
      protocols: peer.protocols.map<String>(_formatProtocol).toList(),
      connectionStatus: _formatConnectionType(peer.connectionType, l10n),
      virtualIpv4: peer.virtualIpv4,
      tags: [
        ?_identityTag(peer.identityType, l10n),
        ?_securityTag(peer.secureAuthLevel, l10n),
      ],
      onTap: onTap,
    );
  }

  /// The local node, whose connection details do not apply.
  factory PeerCardData.fromSelf(Peer self, AppLocalizations l10n) =>
      PeerCardData(
        id: self.id,
        hostname: self.hostname,
        latencyMs: 0,
        protocols: const [],
        connectionStatus: l10n.peerLocal,
        virtualIpv4: self.virtualIpv4,
        isSelf: true,
      );

  // Admins, which hold the network secret, are the usual case.
  static PeerTag? _identityTag(IdentityType type, AppLocalizations l10n) =>
      switch (type) {
        IdentityType.admin => null,
        IdentityType.credential => PeerTag(
          Icons.key_rounded,
          l10n.peerCredential,
          l10n.peerCredentialDescription,
        ),
        IdentityType.sharedNode => PeerTag(
          Icons.public_rounded,
          l10n.peerSharedNode,
          l10n.peerSharedNodeDescription,
        ),
      };

  // Without secure mode there is no handshake to report on.
  static PeerTag? _securityTag(SecureAuthLevel level, AppLocalizations l10n) =>
      switch (level) {
        SecureAuthLevel.none => null,
        SecureAuthLevel.encryptedUnauthenciated => PeerTag(
          Icons.lock_open_rounded,
          l10n.peerUnverified,
          l10n.peerUnverifiedDescription,
          PeerTagTone.caution,
        ),
        SecureAuthLevel.peerVerified => PeerTag(
          Icons.lock_rounded,
          l10n.peerKeyVerified,
          l10n.peerKeyVerifiedDescription,
          PeerTagTone.positive,
        ),
        SecureAuthLevel.networkSecretConfirmed => PeerTag(
          Icons.verified_user_rounded,
          l10n.peerSecretVerified,
          l10n.peerSecretVerifiedDescription,
          PeerTagTone.positive,
        ),
      };

  static String _formatProtocol(NodeProtocol protocol) {
    return protocol.name.toUpperCase();
  }

  static String _formatConnectionType(
    PeerConnectionType type,
    AppLocalizations l10n,
  ) {
    return switch (type) {
      PeerConnectionType.local => l10n.peerLocal,
      PeerConnectionType.direct => 'P2P',
      PeerConnectionType.relay => l10n.peerRelay,
    };
  }

  /// Highlights good and poor latency with color roles, not blends.
  Color getLatencyColor(ColorScheme colors) {
    if (latencyMs < 100) return colors.tertiary;
    if (latencyMs < 300) return colors.onSurfaceVariant;
    return colors.error;
  }
}
