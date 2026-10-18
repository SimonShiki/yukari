import 'dart:io';

import 'package:flutter/services.dart';

class AndroidVpnService {
  static const _channel = MethodChannel('top.simonshiki.yukari/vpn');

  /// Request VPN permission from the system
  /// Returns true if permission is granted
  static Future<bool> requestVpnPermission() =>
      _invokeBool('requestVpnPermission');

  /// Whether the system already lets this app create a TUN device, without
  /// asking the user: the check the background actions may run.
  static Future<bool> hasVpnPermission() => _invokeBool('hasVpnPermission');

  /// Start VPN service and get TUN file descriptor
  /// Returns the TUN fd on success
  static Future<int> startVpn({
    required String networkName,
    required String ipv4,
    required int mtu,
    required List<String> routes,
    String? dns,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('VPN service is only supported on Android');
    }

    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'startVpn',
      {
        'networkName': networkName,
        'ipv4': ipv4,
        'mtu': mtu,
        'routes': routes,
        'dns': dns,
      },
    );

    if (result == null || result['fd'] == null) {
      throw Exception('Failed to start VPN: no TUN fd received');
    }

    return result['fd'] as int;
  }

  /// Stop the VPN service
  static Future<void> stopVpn() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('stopVpn');
  }

  /// Check if VPN is currently active
  static Future<bool> isVpnActive() => _invokeBool('isVpnActive');

  /// Runs the boolean [method]: false where Android is absent, or when the
  /// platform has no answer.
  static Future<bool> _invokeBool(String method) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>(method);
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
