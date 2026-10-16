import 'dart:async';

import '../models/models.dart';
import '../utils/crypto_utils.dart';
import 'network_editor_controller.dart';

/// The editor's secure-mode and VPN-portal actions.
///
/// Their own file: generating a key pair and deriving the public key is one
/// job, and it is the only place that talks to `utils/crypto_utils.dart`.
extension NetworkEditorSecurityActions on NetworkEditorController {
  static const _defaultListen = '0.0.0.0:22022';

  /// Turns secure mode on (generating a key pair when needed) or off, which
  /// keeps the pair.
  void setSecureMode(bool enabled) {
    if (!enabled) {
      update((n) => (n.secureMode ??= SecureMode()).enabled = false);
      return;
    }
    update((n) {
      final mode = n.secureMode ??= SecureMode();
      mode.enabled = true;
      mode.localPrivateKey ??= generatePrivateKey();
    });
    _deriveIfPossible();
  }

  /// Generates a fresh key pair, and the public key that goes with it.
  void generateKeyPair() {
    final privateKey = generatePrivateKey();
    update(
      (n) => (n.secureMode ??= SecureMode())..localPrivateKey = privateKey,
    );
    unawaited(deriveFor(privateKey));
  }

  /// Stores a typed private key; clearing it clears the pair and secure mode.
  void setPrivateKey(String privateKey) {
    if (privateKey.isEmpty) {
      update((n) {
        final mode = n.secureMode;
        if (mode == null) return;
        mode.localPrivateKey = null;
        mode.localPublicKey = null;
        mode.enabled = false;
      });
      return;
    }
    update((n) => (n.secureMode ??= SecureMode()).localPrivateKey = privateKey);
    unawaited(deriveFor(privateKey));
  }

  /// Turns the VPN portal on (creating it when absent) or off, which keeps its
  /// address, key and clients.
  void setVpnPortal(bool enabled) => update((n) {
    final portal = n.vpnPortal ??= VpnPortal(wireguardListen: _defaultListen);
    portal.enabled = enabled;
    if (!enabled) return;
    if (portal.wireguardListen.isEmpty) {
      portal.wireguardListen = _defaultListen;
    }
    portal.wireguardPrivateKey ??= generatePrivateKey();
  });

  /// Stores the address WireGuard clients connect to.
  void setWireguardListen(String address) =>
      update((n) => n.vpnPortal?.wireguardListen = address);

  /// Derives the public key of the private key now on screen, discarding a
  /// derivation whose private key changed or whose controller is gone.
  Future<void> deriveFor(String privateKey) async {
    final String publicKey;
    try {
      publicKey = await derivePublicKey(privateKey);
    } catch (_) {
      return;
    }
    if (isDisposed) return;
    if (working.peek()?.secureMode?.localPrivateKey != privateKey) return;
    update((n) => (n.secureMode ??= SecureMode()).localPublicKey = publicKey);
  }

  void _deriveIfPossible() {
    final privateKey = working.peek()?.secureMode?.localPrivateKey;
    if (privateKey != null) unawaited(deriveFor(privateKey));
  }
}
