import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yukari_core/models/models.dart';

import '../../../controllers/networks/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/form_section/form_section.dart';
import '../../../widgets/list_editor/list_editor_segments.dart';
import 'dns_record_dialog.dart';
import 'dns_zone_card.dart';
import 'dns_zone_dialog.dart';
import 'editor_fields.dart';

/// Full editor for static Magic DNS zones (`[[dns.zone]]`) and records.
class AdvancedDnsZonesSection extends StatelessWidget {
  const AdvancedDnsZonesSection({super.key, required this.controller});

  final NetworkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final magicDnsSignal = editorSwitch(
      controller,
      'flags.acceptDns',
      (n) => n.flags.acceptDns,
    );
    return SignalBuilder(
      builder: (context) {
        final magicDns = magicDnsSignal.value;
        final zones = controller.dnsZones.value;
        if (!magicDns && zones.isEmpty) return const SizedBox.shrink();
        final l10n = context.l10n;
        return FormSection(
          title: l10n.advancedDnsZones,
          icon: Icons.dns_rounded,
          description: l10n.advancedDnsZonesDescription,
          footer: M3EButton.icon(
            onPressed: () => _addZone(context, zones),
            icon: const Icon(Icons.add),
            label: Text(l10n.advancedDnsAddZone),
            style: M3EButtonStyle.tonal,
          ),
          children: [
            if (zones.isEmpty)
              EmptyListSegment(
                icon: Icons.dns_rounded,
                text: l10n.advancedDnsNoZones,
              )
            else
              for (final zone in zones)
                DnsZoneCard(
                  key: ValueKey('dnsZone.${zone.origin}'),
                  zone: zone,
                  onEditZone: () => _editZone(context, zone, zones),
                  onDeleteZone: () => controller.removeDnsZone(zone.origin),
                  onAddRecord: () => _addRecord(context, zone),
                  onEditRecord: (index) =>
                      _editRecord(context, zone, index),
                  onDeleteRecord: (index) =>
                      controller.removeDnsRecord(zone.origin, index),
                ),
          ],
        );
      },
    );
  }

  Future<void> _addZone(BuildContext context, List<DnsZone> zones) async {
    final created = await showDnsZoneDialog(
      context,
      existingOrigins: [for (final zone in zones) zone.origin],
    );
    if (created != null) controller.setDnsZone(created);
  }

  Future<void> _editZone(
    BuildContext context,
    DnsZone zone,
    List<DnsZone> zones,
  ) async {
    final edited = await showDnsZoneDialog(
      context,
      zone: zone,
      existingOrigins: [
        for (final candidate in zones)
          if (candidate.origin != zone.origin) candidate.origin,
      ],
    );
    if (edited != null) {
      controller.setDnsZone(edited, previousOrigin: zone.origin);
    }
  }

  Future<void> _addRecord(BuildContext context, DnsZone zone) async {
    final created = await showDnsRecordDialog(context);
    if (created != null) controller.setDnsRecord(zone.origin, created);
  }

  Future<void> _editRecord(
    BuildContext context,
    DnsZone zone,
    int index,
  ) async {
    final edited = await showDnsRecordDialog(
      context,
      record: zone.records[index],
    );
    if (edited != null) {
      controller.setDnsRecord(zone.origin, edited, index: index);
    }
  }
}
