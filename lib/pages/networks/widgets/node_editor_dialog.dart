import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../models/node.dart';

class NodeEditorDialog extends SignalStatefulWidget {
  const NodeEditorDialog({
    super.key,
    this.initialNode,
    required this.onSave,
    this.existingIds = const [],
  });

  final Node? initialNode;
  final ValueChanged<Node> onSave;
  final List<String> existingIds;

  @override
  State<NodeEditorDialog> createState() => _NodeEditorDialogState();
}

class _NodeEditorDialogState extends State<NodeEditorDialog> {
  late final TextEditingController _idController;
  late final TextEditingController _urlController;
  late final TextEditingController _portController;
  late final TextEditingController _publicKeyController;
  late Set<NodeProtocol> _selectedProtocols;
  final error = signal<String?>(null);

  @override
  void initState() {
    super.initState();
    final node = widget.initialNode;
    _idController = TextEditingController(text: node?.id ?? '');
    _urlController = TextEditingController(text: node?.url.toString() ?? '');
    _portController = TextEditingController(text: node?.port.toString() ?? '');
    _publicKeyController = TextEditingController(text: node?.publicKey ?? '');
    _selectedProtocols = node?.protocols.toSet() ?? {};
  }

  @override
  void dispose() {
    _idController.dispose();
    _urlController.dispose();
    _portController.dispose();
    _publicKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: Text(widget.initialNode == null ? 'Add Peer' : 'Edit Peer'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'Peer ID',
                  helperText: 'Unique identifier for this peer',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => error.value = null,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'example.com',
                  helperText: 'Base URL without port',
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
              const SizedBox(height: 16),
              Text('Protocols', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: NodeProtocol.values.map((protocol) {
                  return FilterChip(
                    label: Text(protocol.name.toUpperCase()),
                    selected: _selectedProtocols.contains(protocol),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedProtocols.add(protocol);
                        } else {
                          _selectedProtocols.remove(protocol);
                        }
                      });
                      error.value = null;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _publicKeyController,
                decoration: const InputDecoration(
                  labelText: 'Public Key (Optional)',
                  helperText: 'Peer\'s public key for secure mode',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
      final id = _idController.text.trim();
      if (id.isEmpty) {
        error.value = 'Peer ID cannot be empty';
        return;
      }

      if (widget.initialNode?.id != id && widget.existingIds.contains(id)) {
        error.value = 'Peer ID already exists';
        return;
      }

      if (_selectedProtocols.isEmpty) {
        error.value = 'At least one protocol must be selected';
        return;
      }

      final port = int.tryParse(_portController.text.trim());
      if (port == null) {
        error.value = 'Port must be a valid number';
        return;
      }

      final publicKey = _publicKeyController.text.trim();

      final node = Node(
        id: id,
        url: Uri.parse(_urlController.text.trim()),
        port: port,
        protocols: _selectedProtocols,
        publicKey: publicKey.isEmpty ? null : publicKey,
      );

      widget.onSave(node);
      Navigator.of(context).pop();
    } catch (e) {
      error.value = e.toString();
    }
  }
}
