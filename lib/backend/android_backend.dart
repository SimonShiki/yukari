import 'dart:async';

import 'package:yukari_core/backend/ffi_backend.dart';
import 'package:yukari_core/bindings/easytier_ffi_native.dart' as native;
import 'package:yukari_core/models/models.dart';

import 'android_vpn.dart';
import 'android_vpn_config.dart';

export 'android_vpn_config.dart';

/// Runs instances in process and shares Android's VpnService across all
/// TUN-enabled networks via EasyTier's shared virtual NIC.
class AndroidBackend extends FfiBackend {
  AndroidBackend({AndroidVpn? vpn})
    : _vpn = vpn ?? systemAndroidVpn,
      _ownsSystemRevoke = vpn == null {
    if (_ownsSystemRevoke) {
      AndroidVpnService.setRevokeHandler(handleVpnRevoked);
    }
  }

  /// The Android VPN the app drives: the method channel, or a test's recorder.
  final AndroidVpn _vpn;
  final bool _ownsSystemRevoke;

  /// Active TUN-enabled members keyed by EasyTier instance (`networkName`).
  final _tunMembers = <String, AndroidVpnMember>{};
  AndroidVpnConfig? _activeVpnConfig;
  int? _activeFd;
  Future<void> _vpnQueue = Future.value();

  @override
  Future<void> start(String id, Network network) async {
    if (network.flags.noTun) {
      await super.start(id, network);
      return;
    }

    final candidate = AndroidVpnMember(network: network);
    await _runVpnOp(() async {
      final conflict = findVpnRouteConflict(_tunMembers.values, candidate);
      if (conflict != null) {
        throw StateError(conflict);
      }

      await super.start(id, network);
      final previousMembers = _tunMembers.keys.toList();
      final previousFd = _activeFd;
      final nextMembers = {..._tunMembers, network.networkName: candidate};
      final nextConfig = buildAndroidVpnConfig(nextMembers.values);

      try {
        for (final name in previousMembers) {
          await _detachQuietly(name);
        }
        final fd = await _startVpn(nextConfig);
        for (final name in nextMembers.keys) {
          await setTunFd(name, fd);
        }
        _tunMembers[network.networkName] = candidate;
        _activeVpnConfig = nextConfig;
        _activeFd = fd;
      } catch (_) {
        await super.stop([network.networkName]);
        if (previousMembers.isEmpty) {
          await _stopVpnQuietly();
          _activeVpnConfig = null;
          _activeFd = null;
        } else if (previousFd != null) {
          for (final name in previousMembers) {
            await _attachQuietly(name, previousFd);
          }
        }
        rethrow;
      }
    });
  }

  /// Stops [names] and updates or tears down the shared VPN service when any
  /// of them participated in it.
  @override
  Future<void> stop(List<String> names) async {
    await super.stop(names);
    await _runVpnOp(() async {
      final removesMember = names.any(_tunMembers.containsKey);
      final retryPendingStop = _tunMembers.isEmpty && _activeVpnConfig != null;
      if (!removesMember && !retryPendingStop) return;

      for (final name in names) {
        _tunMembers.remove(name);
      }
      if (_tunMembers.isEmpty) {
        await _vpn.stop();
        // Keep _activeVpnConfig non-null until stop() succeeds so a later
        // retry or dispose() still releases a live VPN service.
        _activeVpnConfig = null;
        _activeFd = null;
        return;
      }

      final nextConfig = buildAndroidVpnConfig(_tunMembers.values);
      await _rebuildVpn(nextConfig);
    });
  }

  @override
  Future<Map<String, String>> collectInfos() async {
    final infos = await readNetworkInfos();
    if (_tunMembers.isNotEmpty) {
      unawaited(_runVpnOp(() => _reconcileAssignedAddresses(infos)));
    }
    return infos;
  }

  /// Collects raw instance info from FFI. Overridable for tests.
  Future<Map<String, String>> readNetworkInfos() => super.collectInfos();

  /// Detaches TUN instances and clears VPN state after Android revokes the VPN.
  Future<void> handleVpnRevoked() => _runVpnOp(() async {
    final names = _tunMembers.keys.toList();
    for (final name in names) {
      await _detachQuietly(name);
    }
    _tunMembers.clear();
    _activeVpnConfig = null;
    _activeFd = null;
  });

  @override
  Future<TunAccess> tunAccess(Network network) async =>
      network.flags.noTun || await _vpn.requestPermission()
      ? TunAccess.granted
      : TunAccess.denied;

  /// Releases the backend, tearing down any shared VPN service it still owns.
  @override
  Future<void> dispose() async {
    if (_ownsSystemRevoke) {
      AndroidVpnService.setRevokeHandler(null);
    }
    if (_activeVpnConfig != null || _tunMembers.isNotEmpty) {
      for (final name in _tunMembers.keys.toList()) {
        await _detachQuietly(name);
      }
      await _stopVpnQuietly();
      _tunMembers.clear();
      _activeVpnConfig = null;
      _activeFd = null;
    }
    await super.dispose();
  }

  /// Hands [instanceName] the TUN file descriptor [fd]. Overridable, so the
  /// backend can be driven without an EasyTier instance of that name.
  Future<void> setTunFd(String instanceName, int fd) async =>
      native.setTunFd(instanceName, fd);

  Future<T> _runVpnOp<T>(Future<T> Function() action) {
    final next = _vpnQueue.then((_) => action(), onError: (_) => action());
    _vpnQueue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _reconcileAssignedAddresses(Map<String, String> infos) async {
    if (_tunMembers.isEmpty) return;
    var changed = false;
    final updated = <String, AndroidVpnMember>{};
    for (final entry in _tunMembers.entries) {
      final info = infos[entry.key];
      if (info == null) {
        updated[entry.key] = entry.value;
        continue;
      }
      final parsed = parseAssignedAddresses(info);
      final ipv4 = parsed.ipv4 ?? entry.value.assignedIpv4;
      final ipv6 = parsed.ipv6 ?? entry.value.assignedIpv6;
      if (ipv4 != entry.value.assignedIpv4 ||
          ipv6 != entry.value.assignedIpv6) {
        changed = true;
        updated[entry.key] = entry.value.withAssignedAddresses(
          ipv4: ipv4,
          ipv6: ipv6,
        );
      } else {
        updated[entry.key] = entry.value;
      }
    }
    if (!changed) return;

    final nextMembers = <String, AndroidVpnMember>{};
    for (final entry in updated.entries) {
      if (findVpnRouteConflict(nextMembers.values, entry.value) == null) {
        nextMembers[entry.key] = entry.value;
      }
    }
    if (nextMembers.isEmpty) return;

    final nextConfig = buildAndroidVpnConfig(nextMembers.values);
    _tunMembers
      ..clear()
      ..addAll(nextMembers);
    if (nextConfig == _activeVpnConfig) return;

    try {
      await _rebuildVpn(nextConfig);
    } catch (_) {
      // Best-effort reconciliation; the next collection will retry if needed.
    }
  }

  Future<void> _rebuildVpn(AndroidVpnConfig config) async {
    final activeNames = _tunMembers.keys.toList();
    for (final name in activeNames) {
      await _detachQuietly(name);
    }
    final fd = await _startVpn(config);
    for (final name in activeNames) {
      await setTunFd(name, fd);
    }
    _activeVpnConfig = config;
    _activeFd = fd;
  }

  Future<int> _startVpn(AndroidVpnConfig config) => _vpn.start(
    networkName: _vpnLabel(config.networkNames),
    addresses: config.addresses,
    mtu: config.mtu,
    routes: config.routes,
    dns: config.dns,
  );

  Future<void> _detachQuietly(String name) async {
    try {
      await setTunFd(name, 0);
    } catch (_) {
      // Instance may already be gone.
    }
  }

  Future<void> _attachQuietly(String name, int fd) async {
    try {
      await setTunFd(name, fd);
    } catch (_) {
      // Best-effort restoration.
    }
  }

  Future<void> _stopVpnQuietly() async {
    try {
      await _vpn.stop();
    } catch (_) {
      // The service is stopping anyway; nothing is left to report it to.
    }
  }
}

String _vpnLabel(List<String> names) => switch (names.length) {
  0 => 'Yukari',
  1 => names.single,
  _ => '${names.first} (+${names.length - 1})',
};
