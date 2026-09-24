import 'package:material_ui/material_ui.dart';

import '../../models/instance.dart';

class NetworkCard extends StatelessWidget {
  const NetworkCard({
    super.key,
    required this.name,
    required this.running,
    required this.status,
    required this.onToggle,
    required this.menuButton,
  });

  final String name;
  final bool running;
  final InstanceStatus status;
  final ValueChanged<bool>? onToggle;
  final Widget menuButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = switch (this.status) {
      InstanceStatus.stopped => 'Stopped',
      InstanceStatus.running => 'Running',
      InstanceStatus.starting => 'Starting',
      InstanceStatus.stopping => 'Stopping',
      InstanceStatus.failed => 'Failed',
      InstanceStatus.unknown => 'Unknown',
    };
    final badge = Badge(
      backgroundColor: this.status == InstanceStatus.failed
          ? colors.errorContainer
          : (running
                ? colors.primaryContainer
                : colors.surfaceContainerHighest),
      textColor: this.status == InstanceStatus.failed
          ? colors.onErrorContainer
          : (running ? colors.onPrimaryContainer : colors.onSurfaceVariant),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      label: Text(status),
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: '${running ? 'Stop' : 'Start'} $name',
          isSelected: running,
          onPressed: onToggle == null ? null : () => onToggle!(!running),
          icon: const Icon(Icons.play_arrow_rounded),
          selectedIcon: const Icon(Icons.stop_rounded),
          style: IconButton.styleFrom(
            backgroundColor: running ? colors.errorContainer : null,
            foregroundColor: running ? colors.onErrorContainer : null,
          ),
        ),
        menuButton,
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: theme.textTheme.titleSmall)),
                const SizedBox(width: 12),
                badge,
                const SizedBox(width: 8),
                controls,
              ],
            ),
          ],
        );
      },
    );
  }
}
