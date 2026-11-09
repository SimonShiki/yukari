import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

import 'package:yukari_core/models/node.dart';

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
    this.existingNames = const [],
  });

  final Node? initialNode;

  /// Names already used by other peers, which a new node may not repeat.
  final List<String> existingNames;

  @override
  State<NodeFormFields> createState() => NodeFormFieldsState();
}

class NodeFormFieldsState extends State<NodeFormFields> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialNode?.name ?? '',
  );
  late final TextEditingController _urlController = TextEditingController(
    text: widget.initialNode == null ? '' : widget.initialNode!.url.toString(),
  );
  late final TextEditingController _publicKeyController = TextEditingController(
    text: widget.initialNode?.publicKey ?? '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _publicKeyController.dispose();
    super.dispose();
  }

  String? _validateName(String value) {
    final name = value.trim();
    if (name.isEmpty) return context.l10n.networkPeerNameEmpty;
    if (name != widget.initialNode?.name &&
        widget.existingNames.contains(name)) {
      return context.l10n.networkPeerNameExists;
    }
    return null;
  }

  /// The node the fields describe, or null when they do not validate.
  Node? validate() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final publicKey = _publicKeyController.text.trim();
    return Node(
      name: _nameController.text.trim(),
      url: Uri.parse(_urlController.text.trim()),
      publicKey: publicKey.isEmpty ? null : publicKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.l10n.networkPeerName,
              helperText: context.l10n.networkPeerNameHelper,
              border: const OutlineInputBorder(),
            ),
            validator: (v) => _validateName(v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: context.l10n.networkUrl,
              hintText: 'tcp://localhost:1145/',
              helperText: context.l10n.networkUrlHelper,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            validator: (v) => validateNodeUrl(v!),
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
