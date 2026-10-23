import 'dart:io';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:yukari_core/backend/backend.dart';
import '../../l10n/l10n.dart';
import 'package:yukari_core/models/models.dart';
import '../../widgets/dialog/confirm_dialog.dart';

/// Confirms deleting every network in [networks]; a dismissed dialog means no.
///
/// One network keeps the wording that names it, so a single delete reads as it
/// always did; a wider selection is asked about in one question.
Future<bool> confirmDeleteNetworks(
  BuildContext context,
  List<Network> networks,
) {
  final one = networks.length == 1;
  return showConfirmDialog(
    context,
    icon: Icons.delete_outline,
    title: one
        ? context.l10n.networkDeleteTitle
        : context.l10n.networkDeleteSelectedTitle(networks.length),
    message: one
        ? context.l10n.networkDeleteDescription(networks.single.networkName)
        : context.l10n.networkDeleteSelectedDescription,
    confirmLabel: context.l10n.commonDelete,
    destructive: true,
  );
}

/// Explains why [network] cannot create its TUN device, and the two ways out:
/// the settings page, and restarting with the privileges it needs.
Future<void> showTunPermissionWarningDialog(
  BuildContext context,
  Network network,
  NetworkBackend backend, {
  required bool serviceSupported,
}) async {
  final name = network.networkName;
  final reason = Platform.isWindows
      ? context.l10n.networkTunWindows(name)
      : context.l10n.networkTunRoot(name);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.admin_panel_settings_outlined),
      title: Text(context.l10n.networkPrivileges),
      content: Text(
        serviceSupported
            ? '$reason${context.l10n.networkTunServiceOption}'
            : reason,
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        if (serviceSupported)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/settings');
            },
            child: Text(context.l10n.navSettings),
          ),
        if (backend.canElevate)
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await backend.elevate();
            },
            child: Text(context.l10n.networkRestart),
          ),
      ],
    ),
  );
}
