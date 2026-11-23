part of 'android_backend.dart';

extension _AndroidBackendOperations on AndroidBackend {
  Future<T> _runVpnOp<T>(Future<T> Function() action) {
    final next = _vpnQueue.then((_) => action(), onError: (_) => action());
    _vpnQueue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _reconcileAssignedAddresses(Map<String, String> infos) async {
    if (_tunMembers.isEmpty) return;
    var changed = false;
    final seenInfo = <String, String>{};
    final updated = <String, AndroidVpnMember>{};
    for (final entry in _tunMembers.entries) {
      final info = infos[entry.key];
      if (info == null ||
          (!entry.value.network.dhcp && !entry.value.network.dhcpv6)) {
        updated[entry.key] = entry.value;
        continue;
      }
      if (_lastAssignedInfo[entry.key] == info) {
        updated[entry.key] = entry.value;
        continue;
      }
      seenInfo[entry.key] = info;
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
    if (!changed) {
      _lastAssignedInfo.addAll(seenInfo);
      if (!_needsVpnRebuild) return;
      final desiredConfig = buildAndroidVpnConfig(_tunMembers.values);
      if (desiredConfig != _activeVpnConfig) {
        try {
          await _rebuildVpn(desiredConfig);
        } catch (_) {
          // Keep the surviving interface attached and retry on a later poll.
        }
      } else {
        _needsVpnRebuild = false;
      }
      return;
    }

    final nextMembers = <String, AndroidVpnMember>{};
    final conflicts = <String>{};
    for (final entry in updated.entries) {
      final conflict = findVpnRouteConflict(nextMembers.values, entry.value);
      if (conflict == null) {
        nextMembers[entry.key] = entry.value;
        continue;
      }

      conflicts.add(entry.key);
      final previous = _tunMembers[entry.key]!;
      if (findVpnRouteConflict(nextMembers.values, previous) != null) {
        nextMembers
          ..clear()
          ..addAll(_tunMembers);
        conflicts.addAll(updated.keys);
        break;
      }
      nextMembers[entry.key] = previous;
    }
    final nextConfig = buildAndroidVpnConfig(nextMembers.values);
    final cacheableInfo = {
      for (final entry in seenInfo.entries)
        if (!conflicts.contains(entry.key)) entry.key: entry.value,
    };
    if (nextConfig == _activeVpnConfig) {
      _lastAssignedInfo.addAll(cacheableInfo);
      return;
    }

    try {
      await _rebuildVpn(nextConfig);
      _tunMembers
        ..clear()
        ..addAll(nextMembers);
      _lastAssignedInfo.addAll(cacheableInfo);
    } catch (_) {
      // The next collection retries while the assigned address still differs.
    }
  }

  Future<void> _rebuildVpn(
    AndroidVpnConfig config, {
    int? activeFd,
    AndroidVpnConfig? activeConfig,
  }) async {
    final activeNames = _tunMembers.keys.toList();
    for (final name in activeNames) {
      await _detachQuietly(name);
    }
    final previousFd = activeFd ?? _activeFd;
    final previousConfig = activeConfig ?? _activeVpnConfig;
    int? establishedFd;
    try {
      final fd = establishedFd = await _startVpn(config);
      for (final name in activeNames) {
        await setTunFd(name, fd);
      }
      _activeVpnConfig = config;
      _activeFd = fd;
      _needsVpnRebuild = false;
    } catch (_) {
      _needsVpnRebuild = true;
      if (establishedFd == null) {
        if (previousFd != null) {
          for (final name in activeNames) {
            await _attachQuietly(name, previousFd);
          }
        }
        _activeVpnConfig = previousConfig;
        _activeFd = previousFd;
        rethrow;
      }

      for (final name in activeNames) {
        await _detachQuietly(name);
      }
      if (previousConfig == null || previousConfig == config) {
        _activeVpnConfig = config;
        _activeFd = establishedFd;
        rethrow;
      }

      int? rollbackFd;
      try {
        rollbackFd = await _startVpn(previousConfig);
        await _attachAll(activeNames, rollbackFd);
        _activeVpnConfig = previousConfig;
        _activeFd = rollbackFd;
        _needsVpnRebuild = false;
      } catch (_) {
        if (rollbackFd == null) {
          await _attachAll(activeNames, establishedFd);
          _activeVpnConfig = config;
          _activeFd = establishedFd;
        } else {
          _activeVpnConfig = null;
          _activeFd = null;
        }
      }
      rethrow;
    }
  }

  Future<void> _attachAll(List<String> names, int fd) async {
    try {
      for (final name in names) {
        await setTunFd(name, fd);
      }
    } catch (_) {
      for (final name in names) {
        await _detachQuietly(name);
      }
      await _stopVpnQuietly();
      _activeVpnConfig = null;
      _activeFd = null;
      rethrow;
    }
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
