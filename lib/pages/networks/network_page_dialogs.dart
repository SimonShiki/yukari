import 'dart:io';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../models/network.dart';
import '../../signals/backend.dart';

Future<bool> confirmNetworkDeletion(
  BuildContext context,
  Network network,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text(context.l10n.networkDeleteTitle),
        content: Text(
          context.l10n.networkDeleteDescription(network.networkName),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    ) ??
    false;

/// Explains how to give [network] the privileges its TUN device needs.
Future<void> showTunPermissionWarning(BuildContext context, Network network) =>
    showDialog<void>(
      context: context,
      builder: (context) {
        final active = backend.value;
        final serviceSupported = serviceControl.supported;
        return AlertDialog(
          icon: const Icon(Icons.admin_panel_settings_outlined),
          title: Text(context.l10n.networkPrivileges),
          content: Text(
            (Platform.isWindows
                    ? context.l10n.networkTunWindows(network.networkName)
                    : context.l10n.networkTunRoot(network.networkName)) +
                (serviceSupported ? context.l10n.networkTunServiceOption : ''),
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            if (serviceSupported)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/settings');
                },
                child: Text(context.l10n.navSettings),
              ),
            if (active.canElevate)
              FilledButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  // The elevated instance takes over from this one.
                  if (await active.elevate()) exit(0);
                  if (navigator.mounted) navigator.pop();
                },
                child: Text(context.l10n.networkRestart),
              ),
          ],
        );
      },
    );
