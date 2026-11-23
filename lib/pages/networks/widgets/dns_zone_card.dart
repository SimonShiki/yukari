import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari_core/models/models.dart';

import '../../../l10n/l10n.dart';
import '../../../widgets/metadata_chip/metadata_chip.dart';
import '../../../widgets/overflow_text/overflow_text.dart';

/// Displays one static Magic DNS zone and its editable records inside a segment.
class DnsZoneCard extends StatelessWidget {
  const DnsZoneCard({
    super.key,
    required this.zone,
    required this.onEditZone,
    required this.onDeleteZone,
    required this.onAddRecord,
    required this.onEditRecord,
    required this.onDeleteRecord,
  });

  final DnsZone zone;
  final VoidCallback onEditZone;
  final VoidCallback onDeleteZone;
  final VoidCallback onAddRecord;
  final ValueChanged<int> onEditRecord;
  final ValueChanged<int> onDeleteRecord;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final summary = [
      l10n.advancedDnsRecordCount(zone.records.length),
      if (zone.ttl case final int ttl) l10n.advancedDnsTtlSeconds(ttl),
    ].join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        M3EListItem(
          leading: M3EContainer(
            Shapes.c9SidedCookie,
            width: 40,
            height: 40,
            color: colors.secondaryContainer,
            child: Icon(
              Icons.dns_rounded,
              size: 20,
              color: colors.onSecondaryContainer,
            ),
          ),
          headline: OverflowText(zone.origin),
          supportingText: Text(summary),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: l10n.advancedDnsAddRecord,
                onPressed: onAddRecord,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.advancedDnsEditZone,
                onPressed: onEditZone,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.advancedDnsDeleteZone,
                onPressed: onDeleteZone,
              ),
            ],
          ),
        ),
        if (zone.records.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
            child: Text(
              l10n.advancedDnsNoRecords,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: [
                for (var i = 0; i < zone.records.length; i++)
                  _DnsRecordRow(
                    record: zone.records[i],
                    onTap: () => onEditRecord(i),
                    onDelete: () => onDeleteRecord(i),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DnsRecordRow extends StatelessWidget {
  const _DnsRecordRow({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  final DnsRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Row(
            spacing: 8,
            children: [
              MetadataChip.protocol(record.type.wireName),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OverflowText(
                      record.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    OverflowText(
                      record.ttl == null
                          ? record.value
                          : '${record.value} · ${l10n.advancedDnsTtlSeconds(record.ttl!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: l10n.advancedDnsDeleteRecord,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
