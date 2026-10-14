import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../models/node.dart';
import '../../utils/validator.dart';

/// The fields describing one initial peer, shared by the network editor's
/// peer dialog and the bookmarks page's editor.
///
/// The fields own their [Form], so an enclosing dialog validates only its own
/// fields and asks this widget for the node through [NodeFormFieldsState].
class NodeFormFields extends StatefulWidget {
  const NodeFormFields({
    super.key,
    this.initialNode,
    this.existingIds = const [],
  });

  final Node? initialNode;

  /// Ids already used by other peers, which a new node may not repeat.
  final List<String> existingIds;

  @override
  State<NodeFormFields> createState() => NodeFormFieldsState();
}

class NodeFormFieldsState extends State<NodeFormFields> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController = TextEditingController(
    text: widget.initialNode?.id ?? '',
  );
  late final TextEditingController _urlController = TextEditingController(
    text: widget.initialNode == null
        ? ''
        : nodeUrlText(widget.initialNode!.url),
  );
  late final TextEditingController _portController = TextEditingController(
    text: widget.initialNode?.port.toString() ?? '',
  );
  late final TextEditingController _publicKeyController = TextEditingController(
    text: widget.initialNode?.publicKey ?? '',
  );
  late Set<NodeProtocol> _selectedProtocols =
      widget.initialNode?.protocols.toSet() ?? {};

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
    if (id.isEmpty) return context.l10n.networkPeerIdEmpty;
    if (id != widget.initialNode?.id && widget.existingIds.contains(id)) {
      return context.l10n.networkPeerIdExists;
    }
    return null;
  }

  /// The node the fields describe, or null when they do not validate.
  Node? validate() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final publicKey = _publicKeyController.text.trim();
    return Node(
      id: _idController.text.trim(),
      url: Uri.parse(_urlController.text.trim()),
      port: int.parse(_portController.text.trim()),
      protocols: _selectedProtocols.toList(),
      publicKey: publicKey.isEmpty ? null : publicKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _idController,
            decoration: InputDecoration(
              labelText: context.l10n.networkPeerId,
              helperText: context.l10n.networkPeerIdHelper,
              border: const OutlineInputBorder(),
            ),
            validator: (v) => _validateId(v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: context.l10n.networkUrl,
              hintText: 'example.com',
              helperText: context.l10n.networkUrlHelper,
              border: const OutlineInputBorder(),
            ),
            validator: (v) => validateNodeUrl(v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _portController,
            decoration: InputDecoration(
              labelText: context.l10n.networkPort,
              hintText: '11010',
              helperText: context.l10n.networkPortHelper,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (v) => validatePort(v!),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.networkProtocols,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          FormField<Set<NodeProtocol>>(
            initialValue: _selectedProtocols,
            validator: (v) =>
                v!.isEmpty ? context.l10n.networkProtocolRequired : null,
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
            decoration: InputDecoration(
              labelText: context.l10n.networkPublicKey,
              helperText: context.l10n.networkPeerPublicKeyHelper,
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
