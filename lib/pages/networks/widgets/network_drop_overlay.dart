import 'package:flutter/physics.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// The Material 3 Expressive overlay shown while a config file drag hovers
/// over the Networks page.
class NetworkDropOverlay extends StatefulWidget {
  const NetworkDropOverlay({super.key, required this.visible});

  final bool visible;

  @override
  State<NetworkDropOverlay> createState() => _NetworkDropOverlayState();
}

class _NetworkDropOverlayState extends State<NetworkDropOverlay>
    with SingleTickerProviderStateMixin {
  late final _progress = AnimationController.unbounded(vsync: this);
  late bool _mounted = widget.visible;

  @override
  void initState() {
    super.initState();
    if (widget.visible) _progress.value = 1;
  }

  @override
  void didUpdateWidget(covariant NetworkDropOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      setState(() => _mounted = true);
      _animate(1, M3EMotion.standardOverflow);
    } else {
      _animate(0, M3EMotion.standardEffectsFast).whenCompleteOrCancel(() {
        if (mounted && !widget.visible) setState(() => _mounted = false);
      });
    }
  }

  TickerFuture _animate(double target, M3EMotion motion) =>
      _progress.animateWith(
        SpringSimulation(
          SpringDescription.withDampingRatio(
            mass: 1,
            stiffness: motion.stiffness,
            ratio: motion.damping,
          ),
          _progress.value,
          target,
          _progress.velocity,
          snapToEnd: true,
        ),
      );

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_mounted) return const SizedBox.shrink();
    final l10n = context.l10n;
    return IgnorePointer(
      child: ExcludeSemantics(
        excluding: !widget.visible,
        child: Semantics(
          liveRegion: widget.visible,
          excludeSemantics: true,
          label: widget.visible
              ? '${l10n.networkDropTitle}. ${l10n.networkDropDescription}'
              : null,
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, child) => Opacity(
              opacity: _progress.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.95 + 0.05 * _progress.value,
                child: child,
              ),
            ),
            child: const RepaintBoundary(child: _DropOverlaySurface()),
          ),
        ),
      ),
    );
  }
}

class _DropOverlaySurface extends StatelessWidget {
  const _DropOverlaySurface();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.surface.withValues(alpha: 0.86)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: CustomPaint(
            painter: _DashedRRectPainter(
              color: colors.primary,
              fillColor: colors.primaryContainer.withValues(alpha: 0.25),
            ),
          ),
        ),
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: _DropCalloutCard(),
          ),
        ),
      ],
    );
  }
}

class _DropCalloutCard extends StatelessWidget {
  const _DropCalloutCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Material(
        color: colors.primaryContainer,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              M3EContainer(
                Shapes.c9SidedCookie,
                width: 72,
                height: 72,
                color: colors.primary,
                child: Icon(
                  Icons.file_open_outlined,
                  size: 32,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.networkDropTitle,
                style: theme.emphasizedTextTheme.titleLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.networkDropDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.85),
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
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSecondaryContainer,
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

    final outline = Path()..addRRect(rrect);
    final dashed = Path();
    const stride = _dashLength + _gapLength;
    for (final metric in outline.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += stride) {
        final end = (distance + _dashLength).clamp(0.0, metric.length);
        dashed.addPath(metric.extractPath(distance, end), Offset.zero);
      }
    }
    canvas.drawPath(dashed, strokePaint);
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      color != oldDelegate.color || fillColor != oldDelegate.fillColor;
}
