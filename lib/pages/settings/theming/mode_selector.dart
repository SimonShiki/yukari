import 'dart:math' as math;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/theming_controller.dart';
import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/models.dart';

/// The appearance options, in [ThemePreference] order.
const _modes = ThemePreference.values;

/// m3e_core's connected button group gap; the package keeps the token private.
const _connectedGap = 2.0;

/// The window width at which the group stops filling the row and shows labels.
const _wideLayout = 600.0;

/// The widest the group grows on a wide window.
const _maxGroupWidth = 560.0;

/// A connected button group that picks the system, light, dark or OLED
/// appearance: icon-only and filled on compact windows, labelled, capped and
/// centred on wide ones.
class ModeSelector extends StatelessWidget {
  const ModeSelector({super.key, required this.controller});

  /// The group itself, so layout tests can measure it.
  static const groupKey = Key('theming-mode-group');

  final ThemingController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final l10n = context.l10n;
      // Read here, not inside the LayoutBuilder: a layout-phase read would not
      // be subscribed, so tapping a mode would not repaint the group.
      final mode = controller.mode.value;
      final wide = MediaQuery.sizeOf(context).width >= _wideLayout;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 0 : 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxWidth;
            final width = wide
                ? math.min(available, _maxGroupWidth)
                : available;
            final actionWidth = (width - 3 * _connectedGap) / 4;
            final group = SizedBox(
              key: groupKey,
              width: width,
              child: M3EToggleButtonGroup(
                type: M3EButtonGroupType.connected,
                size: wide ? M3EButtonSize.sm : M3EButtonSize.md,
                semanticLabel: l10n.themingMode,
                selectedIndex: _modes.indexOf(mode),
                onSelectedIndexChanged: (index) {
                  if (index != null) controller.selectMode(_modes[index]);
                },
                actions: [
                  _action(
                    Icons.brightness_auto_rounded,
                    l10n.themingModeSystem,
                    actionWidth,
                    wide: wide,
                  ),
                  _action(
                    Icons.light_mode_rounded,
                    l10n.themingModeLight,
                    actionWidth,
                    wide: wide,
                  ),
                  _action(
                    Icons.dark_mode_rounded,
                    l10n.themingModeDark,
                    actionWidth,
                    wide: wide,
                  ),
                  _action(
                    Icons.circle_rounded,
                    l10n.themingModeOled,
                    actionWidth,
                    wide: wide,
                  ),
                ],
              ),
            );
            return wide ? Center(child: group) : group;
          },
        ),
      );
    },
  );

  M3EToggleButtonGroupAction _action(
    IconData icon,
    String label,
    double width, {
    required bool wide,
  }) => M3EToggleButtonGroupAction(
    icon: Icon(icon),
    label: wide ? Text(label) : null,
    semanticLabel: label,
    tooltip: label,
    width: width,
  );
}
