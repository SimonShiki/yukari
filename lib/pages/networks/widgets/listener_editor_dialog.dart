import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../models/node.dart';

class ListenerEditorDialog extends SignalStatefulWidget {
  const ListenerEditorDialog({
    super.key,
    this.initialListener,
    required this.onSave,
  });

  final Uri? initialListener;
  final ValueChanged<Uri> onSave;

  @override
  State<ListenerEditorDialog> createState() => _ListenerEditorDialogState();
}

class _ListenerEditorDialogState extends State<ListenerEditorDialog> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late NodeProtocol _selectedProtocol;
  final error = signal<String?>(null);

  @override
  void initState() {
    super.initState();
    final listener = widget.initialListener;
    _hostController = TextEditingController(text: listener?.host ?? '0.0.0.0');
    _portController = TextEditingController(text: listener?.port.toString() ?? '11010');
    _selectedProtocol = listener != null
        ? NodeProtocol.values.firstWhere(
            (p) => p.name == listener.scheme,
            orElse: () => NodeProtocol.tcp,
          )
        : NodeProtocol.tcp;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: Text(widget.initialListener == null ? 'Add Listener' : 'Edit Listener'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownMenu<NodeProtocol>(
                initialSelection: _selectedProtocol,
                label: const Text('Protocol'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: NodeProtocol.values.map((p) {
                  return DropdownMenuEntry(
                    value: p,
                    label: p.name.toUpperCase(),
                  );
                }).toList(),
                onSelected: (protocol) {
                  if (protocol != null) {
                    setState(() => _selectedProtocol = protocol);
                    error.value = null;
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host',
                  hintText: '0.0.0.0',
                  helperText: 'IP address or hostname to listen on',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => error.value = null,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '11010',
                  helperText: 'Port number (1-65535)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => error.value = null,
              ),
              if (error.value != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error.value!,
                    style: TextStyle(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _handleSave,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _handleSave() {
    try {
      final host = _hostController.text.trim();
      if (host.isEmpty) {
        error.value = 'Host cannot be empty';
        return;
      }

      final port = int.tryParse(_portController.text.trim());
      if (port == null) {
        error.value = 'Port must be a valid number';
        return;
      }

      if (port < 1 || port > 65535) {
        error.value = 'Port must be between 1 and 65535';
        return;
      }

      final listener = Uri(
        scheme: _selectedProtocol.name,
        host: host,
        port: port,
      );

      widget.onSave(listener);
      Navigator.of(context).pop();
    } catch (e) {
      error.value = e.toString();
    }
  }
}
