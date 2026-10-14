import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../models/node.dart';
import '../../../widgets/node_form/node_form_fields.dart';

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
  final _fieldsKey = GlobalKey<NodeFormFieldsState>();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initialNode == null
          ? context.l10n.networkAddPeer
          : context.l10n.networkEditPeer,
    ),
    content: SingleChildScrollView(
      // Room for the first field's floating label, which the scroll view
      // clips when it starts flush with the content edge.
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        // Narrow on phones, and never a wall of text on a wide window.
        width: math.min(MediaQuery.sizeOf(context).width * 0.8, 560),
        child: NodeFormFields(
          key: _fieldsKey,
          initialNode: widget.initialNode,
          existingIds: widget.existingIds,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: _handleSave,
        child: Text(context.l10n.commonSave),
      ),
    ],
  );

  void _handleSave() {
    final node = _fieldsKey.currentState?.validate();
    if (node == null) return;
    widget.onSave(node);
    Navigator.of(context).pop();
  }
}
