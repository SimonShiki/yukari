import 'package:material_ui/material_ui.dart';
import 'package:yukari_core/models/models.dart';

import '../../../l10n/l10n.dart';
import '../../../utils/validator.dart';
import '../../../widgets/dialog/confirm_dialog.dart';
import '../../../widgets/select_item/select_item.dart';

/// Asks for one static DNS record's owner name, type, RDATA value, and TTL.
Future<DnsRecord?> showDnsRecordDialog(
  BuildContext context, {
  DnsRecord? record,
}) => showDialog<DnsRecord>(
  context: context,
  useRootNavigator: false,
  builder: (context) => _DnsRecordDialog(record: record),
);

class _DnsRecordDialog extends StatefulWidget {
  const _DnsRecordDialog({this.record});

  final DnsRecord? record;

  @override
  State<_DnsRecordDialog> createState() => _DnsRecordDialogState();
}

class _DnsRecordDialogState extends State<_DnsRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late DnsRecordType _type = widget.record?.type ?? DnsRecordType.a;
  late final _name = TextEditingController(text: widget.record?.name ?? '');
  late final _value = TextEditingController(text: widget.record?.value ?? '');
  late final _ttl = TextEditingController(
    text: widget.record?.ttl?.toString() ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _ttl.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ttlText = _ttl.text.trim();
    Navigator.of(context).pop(
      DnsRecord(
        name: _name.text.trim(),
        type: _type,
        value: _value.text.trim(),
        ttl: ttlText.isEmpty ? null : int.parse(ttlText),
      ),
    );
  }

  String _valueHint(DnsRecordType type) => switch (type) {
    DnsRecordType.a => '10.0.0.8',
    DnsRecordType.aaaa => 'fd00::8',
    DnsRecordType.cname ||
    DnsRecordType.aname ||
    DnsRecordType.ns ||
    DnsRecordType.ptr => 'host.example.test.',
    DnsRecordType.mx => '10 mail.example.test.',
    DnsRecordType.srv => '10 5 5060 sip.example.test.',
    DnsRecordType.txt => '"local records"',
    DnsRecordType.caa => '0 issue "letsencrypt.org"',
    DnsRecordType.https || DnsRecordType.svcb => '1 . alpn="h2"',
    _ => 'value',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.record == null
            ? l10n.advancedDnsAddRecord
            : l10n.advancedDnsEditRecord,
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
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: SelectItem<DnsRecordType>(
                    icon: Icons.label_outline_rounded,
                    label: l10n.advancedDnsRecordType,
                    value: _type,
                    options: DnsRecordType.values,
                    labelOf: (type) => type.wireName,
                    onSelected: (type) {
                      setState(() => _type = type);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _formKey.currentState?.validate();
                      });
                    },
                  ),
                ),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l10n.advancedDnsRecordName,
                    hintText: 'nas',
                    helperText: l10n.advancedDnsRecordNameHelper,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => validateDnsRecordName(value ?? ''),
                ),
                TextFormField(
                  controller: _value,
                  decoration: InputDecoration(
                    labelText: l10n.advancedDnsRecordValue,
                    hintText: _valueHint(_type),
                    helperText: l10n.advancedDnsRecordValueHelper,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      validateDnsRecordValue(value ?? '', _type),
                ),
                TextFormField(
                  controller: _ttl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.advancedDnsTtl,
                    hintText: '120',
                    helperText: l10n.advancedDnsRecordTtlHelper,
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
