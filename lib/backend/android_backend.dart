import 'dart:async';
import 'dart:isolate';

import 'package:yukari_core/backend/ffi_backend.dart';
import 'package:yukari_core/bindings/easytier_ffi_native.dart' as native;
import 'package:yukari_core/models/models.dart';

import 'android_vpn.dart';
import 'android_vpn_config.dart';

export 'android_vpn_config.dart';

part 'android_backend_operations.dart';

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
  final _lastAssignedInfo = <String, String>{};
  AndroidVpnConfig? _activeVpnConfig;
  int? _activeFd;
  bool _needsVpnRebuild = false;
  Future<void> _vpnQueue = Future.value();
  bool _disposing = false;

  @override
  Future<void> start(String id, Network network) async {
    if (_disposing) throw StateError('Backend disposed');
    if (network.flags.noTun) {
      await _runVpnOp(() => super.start(id, network));
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
      final previousConfig = _activeVpnConfig;
      final nextMembers = {..._tunMembers, network.networkName: candidate};
      final nextConfig = buildAndroidVpnConfig(nextMembers.values);
      int? establishedFd;

      try {
        for (final name in previousMembers) {
          await _detachQuietly(name);
        }
        final fd = establishedFd = await _startVpn(nextConfig);
        for (final name in nextMembers.keys) {
          await setTunFd(name, fd);
        }
        _tunMembers[network.networkName] = candidate;
        _activeVpnConfig = nextConfig;
        _activeFd = fd;
        _needsVpnRebuild = false;
      } catch (_) {
        await super.stop([network.networkName]);
        if (previousMembers.isEmpty) {
          await _stopVpnQuietly();
          _activeVpnConfig = null;
          _activeFd = null;
          _needsVpnRebuild = false;
        } else if (establishedFd != null && previousConfig != null) {
          try {
            await _rebuildVpn(
              previousConfig,
              activeFd: establishedFd,
              activeConfig: nextConfig,
            );
          } catch (_) {
            if (_activeFd == null) {
              await _stopVpnQuietly();
              _activeVpnConfig = null;
            }
          }
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
    await _runVpnOp(() async {
      await super.stop(names);
      final removesMember = names.any(_tunMembers.containsKey);
      final retryPendingStop = _tunMembers.isEmpty && _activeVpnConfig != null;
      if (!removesMember && !retryPendingStop) return;

      for (final name in names) {
        _tunMembers.remove(name);
        _lastAssignedInfo.remove(name);
      }
      if (_tunMembers.isEmpty) {
        await _vpn.stop();
        // Keep _activeVpnConfig non-null until stop() succeeds so a later
        // retry or dispose() still releases a live VPN service.
        _activeVpnConfig = null;
        _activeFd = null;
        _needsVpnRebuild = false;
        return;
      }

      final nextConfig = buildAndroidVpnConfig(_tunMembers.values);
      _needsVpnRebuild = true;
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
    try {
      if (names.isNotEmpty) await super.stop(names);
    } finally {
      _tunMembers.clear();
      _lastAssignedInfo.clear();
      _activeVpnConfig = null;
      _activeFd = null;
      _needsVpnRebuild = false;
    }
  });

  @override
  Future<TunAccess> tunAccess(Network network) async =>
      network.flags.noTun || await _vpn.requestPermission()
      ? TunAccess.granted
      : TunAccess.denied;

  /// Releases the backend, tearing down any shared VPN service it still owns.
  @override
  Future<void> dispose() async {
    _disposing = true;
    if (_ownsSystemRevoke) {
      AndroidVpnService.setRevokeHandler(null);
    }
    await _runVpnOp(() async {
      if (_activeVpnConfig != null || _tunMembers.isNotEmpty) {
        for (final name in _tunMembers.keys.toList()) {
          await _detachQuietly(name);
        }
        await _stopVpnQuietly();
        _tunMembers.clear();
        _lastAssignedInfo.clear();
        _activeVpnConfig = null;
        _activeFd = null;
        _needsVpnRebuild = false;
      }
    });
    await super.dispose();
  }

  /// Hands [instanceName] the TUN file descriptor [fd]. Overridable, so the
  /// backend can be driven without an EasyTier instance of that name.
  Future<void> setTunFd(String instanceName, int fd) async =>
      await Isolate.run(() => native.setTunFd(instanceName, fd));
}
