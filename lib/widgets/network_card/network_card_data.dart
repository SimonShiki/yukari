import 'package:material_ui/material_ui.dart';

import '../../models/instance.dart';

class NetworkCardData {
  const NetworkCardData({
    required this.id,
    required this.name,
    required this.status,
    required this.running,
    required this.onOpen,
    required this.onEdit,
    required this.onLog,
    required this.onDelete,
    this.onToggle,
    this.busy = false,
  });

  /// Key of the network in the saved network collection.
  final String id;
  final String name;
  final InstanceStatus status;
  final bool running;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onLog;
  final Future<void> Function() onDelete;
  final ValueChanged<bool>? onToggle;
}
