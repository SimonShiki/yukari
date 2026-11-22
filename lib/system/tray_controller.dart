import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

import 'package:yukari_core/backend/backend.dart';

import 'package:yukari_core/models/models.dart';

import '../signals/backend.dart' as active;
import '../signals/instances.dart' as running;
import '../signals/locale.dart';
import '../signals/networks.dart' as saved;
import '../signals/settings.dart';
import 'native_tray_platform.dart';
import 'tray_menu.dart';
import 'tray_networks.dart';
import 'tray_platform.dart';

part 'tray_controller_close.dart';
part 'tray_controller_menu.dart';

/// Starts the system tray for this session.
///
/// Runs on platforms with system tray support. A failure is
/// swallowed: the tray is optional, and it must never keep the app from
/// starting or closing normally.
void launchSystemTray() {
  if (systemTraySupported) unawaited(_launch());
}

Future<void> _launch() async {
  try {
    final controller = TrayController(
      platform: NativeTrayPlatform(),
      binding: WidgetsBinding.instance,
    );
    await controller.start();
  } catch (_) {
    // No tray on this session; everything else keeps working.
  }
}

/// Where the one-time "still running in the tray" notice was remembered.
const _noticeShownKey = 'tray.noticeShown';

/// The tray icons: the bare mark, white on dark panels and brand purple on
/// light ones.
const Map<Brightness, String> _icons = {
  Brightness.dark: 'assets/generated/yukari-tray-dark.png',
  Brightness.light: 'assets/generated/yukari-tray-light.png',
};

/// The icon the tray draws on a panel of [brightness].
String trayIconFor(Brightness brightness) => _icons[brightness]!;

/// Keeps the app in the system tray: the icon and its menu, the close button
/// that hides the window, and the one-time notice that says the app runs on.
///
/// The signals it reads are the same stores every page uses, so the menu shows
/// what the app shows, and it acts through those stores and the active backend
/// ([TrayNetworkActions]). While an instance runs, it refreshes the running
/// instances at [refreshInterval] to update the peer counts.
///
/// The tray is optional, and a desktop may show no icon even where the OS has
/// trays. Without one, [start] keeps the close button exiting the app, so the
/// window can never be hidden somewhere there is no way back from.
class TrayController with WidgetsBindingObserver {
  TrayController({
    required this.platform,
    ReadonlySignal<NetworkBackend>? backend,
    this.refreshInterval = const Duration(seconds: 2),
    this.binding,
  }) : _backend = backend ?? active.backend,
       _networks = TrayNetworkActions(backend ?? active.backend);

  /// The native tray, window and notification calls.
  final TrayPlatform platform;

  /// How often the menu refreshes peer counts while an instance runs.
  final Duration refreshInterval;

  /// Reports platform brightness when set; null in tests that drive
  /// [setBrightness] themselves.
  final WidgetsBinding? binding;

  final ReadonlySignal<NetworkBackend> _backend;

  /// The start/stop actions, on the shared stores and the active backend.
  final TrayNetworkActions _networks;

  final List<EffectCleanup> _effects = [];

  Timer? _refreshTimer;
  TrayMenu? _pendingMenu;
  bool _menuScheduled = false;
  Brightness _brightness = Brightness.light;
  bool? _noticeShown;
  bool _noticePending = false;
  bool _trayExists = false;
  bool _started = false;
  bool _disposed = false;

  /// Shows the tray and starts following the settings, networks and instances.
  ///
  /// Without a tray icon, closing exits after pending edits are saved.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    binding?.addObserver(this);
    _brightness =
        binding?.platformDispatcher.platformBrightness ?? Brightness.light;
    _trayExists = await platform.initialize();
    settings.behavior.setTrayAvailable(_trayExists);
    platform.interceptClose(_closeRequested);
    if (!_trayExists) return;
    // The two effects run once now too, so the icon and menu start in step.
    _effects.add(
      effect(() {
        final enabled = settings.behavior.useSystemTray.value;
        if (_disposed) return;
        unawaited(_applyEnabled(enabled));
      }),
    );
    _effects.add(
      effect(() {
        final menu = _buildMenu();
        if (_disposed) return;
        _syncRefreshTimer(running.instances.peek().isNotEmpty);
        _scheduleMenuUpdate(menu);
      }),
    );
    await _networks.refresh();
  }

  /// Draws the icon for [brightness]'s panels, and follows later changes.
  void setBrightness(Brightness brightness) {
    if (_brightness == brightness) return;
    _brightness = brightness;
    if (_disposed || !_trayExists || !settings.behavior.useSystemTray.peek()) {
      return;
    }
    unawaited(platform.setIcon(trayIconFor(brightness)));
  }

  @override
  void didChangePlatformBrightness() => setBrightness(
    binding?.platformDispatcher.platformBrightness ?? _brightness,
  );

  /// The periodic peer count refresh exists exactly while an instance runs.
  void _syncRefreshTimer(bool hasRunning) {
    if (hasRunning && _refreshTimer == null) {
      _refreshTimer = Timer.periodic(
        refreshInterval,
        (_) => unawaited(_networks.refresh()),
      );
    } else if (!hasRunning) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  /// Stops the effects and the refresh timer; the tray icon stays for
  /// [TrayPlatform.quit].
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    for (final cleanup in _effects) {
      cleanup();
    }
    _effects.clear();
    binding?.removeObserver(this);
    settings.behavior.setTrayAvailable(false);
  }
}
