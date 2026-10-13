import 'package:material_ui/material_ui.dart';

import '../../../models/node.dart';
import '../../../utils/validator.dart';

class NodeEditorDialog extends StatefulWidget {
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _urlController;
  late final TextEditingController _portController;
  late final TextEditingController _publicKeyController;
  late Set<NodeProtocol> _selectedProtocols;

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

  String? _validateId(String value) {
    final id = value.trim();
    if (id.isEmpty) return 'Peer ID cannot be empty';
    if (id != widget.initialNode?.id && widget.existingIds.contains(id)) {
      return 'Peer ID already exists';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.initialNode == null ? 'Add Peer' : 'Edit Peer'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'Peer ID',
                    helperText: 'Unique identifier for this peer',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _validateId(v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    hintText: 'example.com',
                    helperText: 'Base URL without port',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => validateNodeUrl(v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '11010',
                    helperText: 'Port number (1-65535)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => validatePort(v!),
                ),
                const SizedBox(height: 16),
                Text('Protocols', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                FormField<Set<NodeProtocol>>(
                  initialValue: _selectedProtocols,
                  validator: (v) => v!.isEmpty
                      ? 'At least one protocol must be selected'
                      : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: NodeProtocol.values.map((protocol) {
                          return FilterChip(
                            label: Text(protocol.name.toUpperCase()),
                            selected: field.value!.contains(protocol),
                            onSelected: (selected) {
                              _selectedProtocols = {...field.value!};
                              selected
                                  ? _selectedProtocols.add(protocol)
                                  : _selectedProtocols.remove(protocol);
                              field.didChange(_selectedProtocols);
                            },
                          );
                        }).toList(),
                      ),
                      if (field.errorText case final error?)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 12),
                          child: Text(
                            error,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _publicKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Public Key (Optional)',
                    helperText: 'Peer\'s public key for secure mode',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _handleSave, child: const Text('Save')),
      ],
    );
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;
    final publicKey = _publicKeyController.text.trim();
    widget.onSave(
      Node(
        id: _idController.text.trim(),
        url: Uri.parse(_urlController.text.trim()),
        port: int.parse(_portController.text.trim()),
        protocols: _selectedProtocols.toList(),
        publicKey: publicKey.isEmpty ? null : publicKey,
      ),
    );
    Navigator.of(context).pop();
  }
}
