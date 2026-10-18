import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/backend.dart';
import '../../../widgets/dialog/confirm_dialog.dart';

/// Asks whether switching to [kind] may stop the [count] running networks.
///
/// The networks stay running unless the user confirms: a dismissed dialog
/// means no.
Future<bool> confirmSwitchBackend(
  BuildContext context,
  BackendKind kind,
  int count,
) {
  final l10n = context.l10n;
  final toService = kind == BackendKind.service;
  return showConfirmDialog(
    context,
    icon: Icons.swap_horiz_rounded,
    title: toService ? l10n.settingsSwitchToService : l10n.settingsSwitchToApp,
    message: toService
        ? l10n.settingsSwitchToServiceMessage(count)
        : l10n.settingsSwitchToAppMessage(count),
    confirmLabel: l10n.settingsSwitch,
  );
}
