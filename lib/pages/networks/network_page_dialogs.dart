import 'dart:io';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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
        title: const Text('Delete network?'),
        content: Text(
          'Delete “${network.networkName}”? Its running instance '
          'will be stopped. This cannot be undone.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

/// Explains how to give [network] the privileges its TUN device needs.
Future<void> showTunPermissionWarning(
  BuildContext context,
  Network network,
) => showDialog<void>(
  context: context,
  builder: (context) {
    final active = backend.value;
    final serviceSupported = serviceControl.supported;
    return AlertDialog(
      icon: const Icon(Icons.admin_panel_settings_outlined),
      title: const Text('Privileges required'),
      content: Text(
        '"${network.networkName}" needs '
        '${Platform.isWindows ? 'administrator' : 'root'} privileges to '
        'create its TUN device. You can:\n\n'
        '• Restart Yukari ${Platform.isWindows ? 'as administrator' : 'as root'}.\n'
        '• Turn on "Disable TUN mode" for this network.'
        '${serviceSupported ? '\n• Use service mode in Settings, which runs '
            'networks in the background with full privileges.' : ''}',
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (serviceSupported)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/settings');
            },
            child: const Text('Settings'),
          ),
        if (active.canElevate)
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              // The elevated instance takes over from this one.
              if (await active.elevate()) exit(0);
              if (navigator.mounted) navigator.pop();
            },
            child: const Text('Restart'),
          ),
      ],
    );
  },
);
