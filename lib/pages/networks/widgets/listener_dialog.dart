import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../models/models.dart';
import '../../../utils/validator.dart';
import 'editor_fields.dart';

/// Asks for one listener address; null when dismissed or still invalid.
Future<Uri?> showListenerDialog(BuildContext context, {Uri? listener}) =>
    showDialog<Uri>(
      context: context,
      builder: (context) => _ListenerDialog(listener: listener),
    );

class _ListenerDialog extends StatefulWidget {
  const _ListenerDialog({this.listener});

  final Uri? listener;

  @override
  State<_ListenerDialog> createState() => _ListenerDialogState();
}

class _ListenerDialogState extends State<_ListenerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _host = TextEditingController(
    text: widget.listener?.host ?? '0.0.0.0',
  );
  late final _port = TextEditingController(
    text: '${widget.listener?.port ?? 11010}',
  );
  late NodeProtocol _protocol = _schemeOf(widget.listener) ?? NodeProtocol.tcp;

  /// The protocol an edited listener already uses, when it is one we offer.
  static NodeProtocol? _schemeOf(Uri? listener) {
    for (final protocol in NodeProtocol.values) {
      if (protocol.name == listener?.scheme) return protocol;
    }
    return null;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      Uri(
        scheme: _protocol.name,
        host: _host.text.trim(),
        port: int.parse(_port.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.listener == null
            ? l10n.networkAddListener
            : l10n.networkEditListenerNamed(widget.listener.toString()),
      ),
      content: SizedBox(
        width: math.min(MediaQuery.sizeOf(context).width * 0.8, 560),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                EditorDropdown<NodeProtocol>(
                  label: l10n.networkProtocol,
                  helper: null,
                  value: _protocol,
                  options: NodeProtocol.values,
                  labelOf: (protocol) => protocol.name.toUpperCase(),
                  onSelected: (protocol) => setState(() => _protocol = protocol),
                ),
                TextFormField(
                  controller: _host,
                  decoration: InputDecoration(
                    labelText: l10n.networkHost,
                    helperText: l10n.networkListenHostHelper,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => validateHost(value ?? ''),
                ),
                TextFormField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.networkPort,
                    helperText: l10n.networkPortHelper,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => validatePort(value ?? ''),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}
