import 'dart:io';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../backend/backend.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../widgets/dialog/confirm_dialog.dart';

/// Confirms deleting [network]; a dismissed dialog means no.
Future<bool> confirmDeleteNetwork(BuildContext context, Network network) =>
    showConfirmDialog(
      context,
      icon: Icons.delete_outline,
      title: context.l10n.networkDeleteTitle,
      message: context.l10n.networkDeleteDescription(network.networkName),
      confirmLabel: context.l10n.commonDelete,
      destructive: true,
    );

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
