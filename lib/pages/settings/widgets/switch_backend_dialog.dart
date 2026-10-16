import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../models/backend.dart';

/// Asks whether switching to [kind] may stop the [count] running networks.
///
/// The networks stay running unless the user confirms: a dismissed dialog
/// means no.
Future<bool> confirmSwitchBackend(
  BuildContext context,
  BackendKind kind,
  int count,
) async {
  final l10n = context.l10n;
  final toService = kind == BackendKind.service;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.swap_horiz_rounded),
      title: Text(
        toService ? l10n.settingsSwitchToService : l10n.settingsSwitchToApp,
      ),
      content: Text(
        toService
            ? l10n.settingsSwitchToServiceMessage(count)
            : l10n.settingsSwitchToAppMessage(count),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.settingsSwitch),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
