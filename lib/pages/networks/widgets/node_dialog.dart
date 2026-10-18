import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'package:yukari_core/models/models.dart';
import '../../../widgets/dialog/confirm_dialog.dart';
import '../../../widgets/node_form/node_form_fields.dart';

/// Asks for one initial peer; null when dismissed or still invalid.
Future<Node?> showNodeDialog(
  BuildContext context, {
  Node? node,
  List<String> existingIds = const [],
}) async {
  final fields = GlobalKey<NodeFormFieldsState>();
  return showDialog<Node>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        node == null
            ? context.l10n.networkAddPeer
            : context.l10n.networkEditPeerNamed(node.id),
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SizedBox(
          width: dialogContentWidth(context),
          child: SingleChildScrollView(
            child: NodeFormFields(
              key: fields,
              initialNode: node,
              existingIds: existingIds,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          // Every invalid field is flagged and the dialog stays open.
          onPressed: () {
            final peer = fields.currentState?.validate();
            if (peer != null) Navigator.of(context).pop(peer);
          },
          child: Text(context.l10n.commonSave),
        ),
      ],
    ),
  );
}
