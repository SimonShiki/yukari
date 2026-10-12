import 'package:material_ui/material_ui.dart';

import '../../../models/node.dart';
import '../../../utils/validator.dart';

class ListenerEditorDialog extends StatefulWidget {
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late NodeProtocol _selectedProtocol;

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
    return AlertDialog(
      title: Text(widget.initialListener == null ? 'Add Listener' : 'Edit Listener'),
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
                    if (protocol != null) _selectedProtocol = protocol;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host',
                    hintText: '0.0.0.0',
                    helperText: 'IP address or hostname to listen on',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => validateHost(v!),
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
        FilledButton(
          onPressed: _handleSave,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSave(Uri(
      scheme: _selectedProtocol.name,
      host: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
    ));
    Navigator.of(context).pop();
  }
}
