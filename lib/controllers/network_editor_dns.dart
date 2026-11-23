part of 'network_editor_controller.dart';

/// Magic DNS domain, static zones, and records edited in place.
extension NetworkEditorDns on NetworkEditorController {
  /// Sets the Magic DNS root domain and keeps legacy `flags.dnsZone` synced.
  void setDnsDomain(String domain) {
    final trimmed = domain.trim();
    update((n) {
      n.flags.dnsZone = trimmed;
      if (n.dns != null) {
        if (isDefaultDnsDomain(trimmed) && n.dns!.zones.isEmpty) {
          n.dns = null;
        } else {
          n.dns!.domain = isDefaultDnsDomain(trimmed) ? null : trimmed;
        }
      } else if (!isDefaultDnsDomain(trimmed)) {
        n.dns = DnsConfig(domain: trimmed);
      }
    });
  }

  /// Adds [zone], or replaces the zone stored under [previousOrigin].
  void setDnsZone(DnsZone zone, {String? previousOrigin}) {
    final key = normalizeDnsName(previousOrigin ?? zone.origin);
    update((n) {
      final legacy = n.flags.dnsZone.trim();
      final dns = n.dns ??= DnsConfig(
        domain: legacy.isNotEmpty && !isDefaultDnsDomain(legacy)
            ? legacy
            : null,
      );
      final zones = [...dns.zones];
      final index = zones.indexWhere(
        (existing) => normalizeDnsName(existing.origin) == key,
      );
      if (index < 0) {
        zones.add(zone);
      } else {
        zones[index] = zone;
      }
      dns.zones = zones;
    });
    _syncDnsZones();
  }

  /// Removes the static DNS zone matching [origin].
  void removeDnsZone(String origin) {
    final key = normalizeDnsName(origin);
    update((n) {
      final dns = n.dns;
      if (dns == null) return;
      dns.zones = [
        for (final zone in dns.zones)
          if (normalizeDnsName(zone.origin) != key) zone,
      ];
      final domain = dns.domain?.trim();
      if (dns.zones.isEmpty &&
          (domain == null || domain.isEmpty || isDefaultDnsDomain(domain))) {
        n.dns = null;
      }
    });
    _syncDnsZones();
  }

  /// Adds [record] to [zoneOrigin], or replaces the record at [index].
  void setDnsRecord(String zoneOrigin, DnsRecord record, {int? index}) {
    final key = normalizeDnsName(zoneOrigin);
    update((n) {
      final dns = n.dns;
      if (dns == null) return;
      final zoneIndex = dns.zones.indexWhere(
        (existing) => normalizeDnsName(existing.origin) == key,
      );
      if (zoneIndex < 0) return;
      final zone = dns.zones[zoneIndex];
      final records = [...zone.records];
      if (index == null || index < 0 || index >= records.length) {
        records.add(record);
      } else {
        records[index] = record;
      }
      zone.records = records;
    });
    _syncDnsZones();
  }

  /// Removes the record at [index] from [zoneOrigin].
  void removeDnsRecord(String zoneOrigin, int index) {
    final key = normalizeDnsName(zoneOrigin);
    update((n) {
      final dns = n.dns;
      if (dns == null) return;
      final zoneIndex = dns.zones.indexWhere(
        (existing) => normalizeDnsName(existing.origin) == key,
      );
      if (zoneIndex < 0) return;
      final zone = dns.zones[zoneIndex];
      if (index < 0 || index >= zone.records.length) return;
      final records = [...zone.records]..removeAt(index);
      zone.records = records;
    });
    _syncDnsZones();
  }

  void _syncDnsZones() {
    if (_disposed) return;
    dnsZones.value = List.unmodifiable(working.peek()?.dns?.zones ?? const []);
  }
}
