import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/networks/network_page_controller.dart';
import '../../../l10n/l10n.dart';

/// Whether this desktop platform supports dropping config files onto the page.
bool get isConfigDropSupported =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// Accepts dropped `.toml` config files over [child] on desktop platforms and
/// paints [NetworkDropOverlay] while a drag hovers.
class NetworkDropZone extends StatelessWidget {
  const NetworkDropZone({
    super.key,
    required this.controller,
    required this.child,
  });

  final NetworkPageController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isConfigDropSupported) return child;
    final active =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? false);
    return DropTarget(
      enable: active,
      onDragEntered: (_) => controller.setDraggingConfig(true),
      onDragExited: (_) => controller.setDraggingConfig(false),
      onDragDone: (details) => unawaited(
        controller.importDroppedFiles([
          for (final file in details.files) file.path,
        ]),
      ),
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: SignalBuilder(
              builder: (context) =>
                  NetworkDropOverlay(visible: controller.draggingConfig.value),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Material 3 Expressive overlay shown while a config file drag hovers
/// over the Networks page.
class NetworkDropOverlay extends StatelessWidget {
  const NetworkDropOverlay({super.key, required this.visible});

  final bool visible;

  static const Duration _enterDuration = Duration(milliseconds: 200);
  static const Duration _exitDuration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final duration = visible ? _enterDuration : _exitDuration;

    return IgnorePointer(
      child: ExcludeSemantics(
        excluding: !visible,
        child: Semantics(
          liveRegion: visible,
          label: visible
              ? '${l10n.networkDropTitle}. ${l10n.networkDropDescription}'
              : null,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: visible ? 1 : 0.95,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: colors.surface.withValues(alpha: 0.86)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomPaint(
                      painter: _DashedRRectPainter(
                        color: colors.primary,
                        fillColor: colors.primaryContainer.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Material(
                          color: colors.primaryContainer,
                          elevation: 2,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(28)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 28,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                M3EContainer(
                                  Shapes.c9SidedCookie,
                                  width: 72,
                                  height: 72,
                                  color: colors.primary,
                                  child: Icon(
                                    Icons.file_download_outlined,
                                    size: 32,
                                    color: colors.onPrimary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.networkDropTitle,
                                  style: theme.emphasizedTextTheme.titleLarge
                                      ?.copyWith(
                                        color: colors.onPrimaryContainer,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.networkDropDescription,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onPrimaryContainer.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: colors.secondaryContainer,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      spacing: 6,
                                      children: [
                                        Icon(
                                          Icons.description_outlined,
                                          size: 14,
                                          color: colors.onSecondaryContainer,
                                        ),
                                        Text(
                                          '.toml',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color:
                                                    colors.onSecondaryContainer,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.fillColor});

  static const double _radius = 28;
  static const double _strokeWidth = 2.5;
  static const double _dashLength = 10;
  static const double _gapLength = 8;

  final Color color;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(_strokeWidth / 2),
      const Radius.circular(_radius),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()..addRRect(rrect);
    const stride = _dashLength + _gapLength;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += stride) {
        final end = (distance + _dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      color != oldDelegate.color || fillColor != oldDelegate.fillColor;
}
