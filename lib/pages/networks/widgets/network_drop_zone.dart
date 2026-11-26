import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/networks/network_page_controller.dart';
import 'network_drop_overlay.dart';

/// Whether this desktop platform supports dropping config files onto the page.
bool get isConfigDropSupported => Platform.isLinux || Platform.isWindows;

/// Accepts dropped `.toml` config files over [child] on desktop platforms and
/// paints [NetworkDropOverlay] while a drag hovers.
class NetworkDropZone extends StatefulWidget {
  const NetworkDropZone({
    super.key,
    required this.controller,
    required this.child,
  });

  final NetworkPageController controller;
  final Widget child;

  @override
  State<NetworkDropZone> createState() => _NetworkDropZoneState();
}

class _NetworkDropZoneState extends State<NetworkDropZone> {
  bool _hovering = false;

  void _syncDragging(
    NetworkPageController controller,
    bool Function() target,
  ) {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => controller.setDraggingConfig(target()),
      );
      return;
    }
    controller.setDraggingConfig(target());
  }

  @override
  void didUpdateWidget(covariant NetworkDropZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller && _hovering) {
      _syncDragging(oldWidget.controller, () => false);
      _syncDragging(widget.controller, () => mounted && _hovering);
    }
  }

  @override
  void dispose() {
    if (_hovering || widget.controller.draggingConfig.peek()) {
      _hovering = false;
      _syncDragging(widget.controller, () => false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isConfigDropSupported) return widget.child;
    final active =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? false);
    return DropTarget(
      enable: active,
      onDragEntered: (_) {
        _hovering = true;
        _syncDragging(widget.controller, () => mounted && _hovering);
      },
      onDragExited: (_) {
        _hovering = false;
        _syncDragging(widget.controller, () => mounted && _hovering);
      },
      onDragDone: (details) => unawaited(
        widget.controller.importDroppedFiles([
          for (final file in details.files) file.path,
        ]),
      ),
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: SignalBuilder(
              builder: (context) => NetworkDropOverlay(
                visible: widget.controller.draggingConfig.value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
