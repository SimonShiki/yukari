import 'package:material_ui/material_ui.dart';
import 'package:yukari_core/models/models.dart';

import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/dialog/confirm_dialog.dart';

/// Asks for a static DNS zone's origin and optional default TTL.
Future<DnsZone?> showDnsZoneDialog(
  BuildContext context, {
  DnsZone? zone,
  required Iterable<String> existingOrigins,
}) => showDialog<DnsZone>(
  context: context,
  useRootNavigator: false,
  builder: (context) =>
      _DnsZoneDialog(zone: zone, existingOrigins: existingOrigins),
);

class _DnsZoneDialog extends StatefulWidget {
  const _DnsZoneDialog({this.zone, required this.existingOrigins});

  final DnsZone? zone;
  final Iterable<String> existingOrigins;

  @override
  State<_DnsZoneDialog> createState() => _DnsZoneDialogState();
}

class _DnsZoneDialogState extends State<_DnsZoneDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _origin = TextEditingController(text: widget.zone?.origin ?? '');
  late final _ttl = TextEditingController(
    text: widget.zone?.ttl?.toString() ?? '',
  );

  @override
  void dispose() {
    _origin.dispose();
    _ttl.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ttlText = _ttl.text.trim();
    Navigator.of(context).pop(
      DnsZone(
        origin: _origin.text.trim(),
        ttl: ttlText.isEmpty ? null : int.parse(ttlText),
        records: [
          for (final record in widget.zone?.records ?? const <DnsRecord>[])
            DnsRecord(
              name: record.name,
              type: record.type,
              value: record.value,
              ttl: record.ttl,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.zone == null ? l10n.advancedDnsAddZone : l10n.advancedDnsEditZone,
      ),
      content: SizedBox(
        width: dialogContentWidth(context),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                TextFormField(
                  controller: _origin,
                  decoration: InputDecoration(
                    labelText: l10n.advancedDnsZoneOrigin,
                    hintText: 'example.test.',
                    helperText: l10n.advancedDnsZoneOriginHelper,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => validateDnsOrigin(
                    value ?? '',
                    existingOrigins: widget.existingOrigins,
                  ),
                ),
                TextFormField(
                  controller: _ttl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.advancedDnsTtl,
                    hintText: '60',
                    helperText: l10n.advancedDnsZoneTtlHelper,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => validateDnsTtl(value ?? ''),
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
