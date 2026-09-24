import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../models/instance.dart';
import '../../models/network.dart';
import '../../utils/tun_helper.dart';

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

void showNetworkLog(BuildContext context, Instance instance) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${instance.network.networkName} log'),
      scrollable: true,
      content: SelectableText(
        instance.events.isEmpty ? 'No events yet.' : instance.events.join('\n'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<bool> showTunPermissionWarning(
  BuildContext context,
  Network network,
) async {
  if (Platform.isWindows) {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_outlined),
        title: const Text('Administrator privileges required'),
        content: Text(
              'Network requires administrator/root '
              'privileges to proxy your traffic system-wide.\n\n'
              'Click ok to try get that permission, or turn on `No TUN` for this network.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final success = await requestTunPermission();
              if (success) {
                // Elevation request initiated, close the app
                exit(0);
              }
              if (navigator.mounted) {
                navigator.pop(false);
              }
            },
            child: const Text('Elevate'),
          ),
        ],
      ),
    ) ?? false;
  } else {
    // Unix/Linux/macOS
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_outlined),
        title: const Text('Root privileges required'),
        content: Text(
          'Network "${network.networkName}" requires root privileges '
          'to create a TUN device.\n\n'
          'Please restart the application with sudo or as root and try again.',
        ),
        actions: [
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('OK'),
          ),
        ],
      ),
    ) ?? false;
  }
}
