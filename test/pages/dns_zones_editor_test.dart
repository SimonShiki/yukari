import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/network_editor_controller.dart';
import 'package:yukari/pages/networks/network_editor_page.dart';
import 'package:yukari/signals/networks.dart' as saved;
import 'package:yukari_core/models/models.dart';

import '../networks_fixture.dart';
import 'network_test_support.dart';

void main() {
  useDeterministicCursor();

  late NetworkEditorController controller;

  Future<void> pumpEditor(WidgetTester tester, {String id = 'n1'}) async {
    controller = NetworkEditorController(id: id, showMessage: (_) {});
    addTearDown(controller.dispose);
    await pumpApp(tester, NetworkEditorPage(id: id, controller: controller));
  }

  Future<void> submitDialog(WidgetTester tester) async {
    await tester.tap(find.text(strings.commonSave));
    await tester.pumpAndSettle();
    await tester.runAsync(saved.settled);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'static DNS zones editor adds, validates, edits, and deletes zones and records',
    (tester) async {
      await tester.runAsync(seedNetworks);
      await pumpEditor(tester);
      await switchTab(tester, strings.networkAdvanced);

      // Hidden when Magic DNS is off and no zones exist.
      expect(find.text(strings.advancedDnsZones), findsNothing);

      // Enable Magic DNS: section and empty state appear.
      await tapSaving(tester, find.text(strings.advancedMagicDns));
      expect(find.text(strings.advancedDnsZones), findsOneWidget);
      expect(find.text(strings.advancedDnsNoZones), findsOneWidget);

      // Add a zone.
      await tapSaving(tester, find.text(strings.advancedDnsAddZone));
      expect(find.text(strings.advancedDnsAddZone), findsWidgets);

      // Reject empty origin.
      await tester.tap(find.text(strings.commonSave));
      await tester.pumpAndSettle();
      expect(find.text(strings.validationDnsOriginEmpty), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, strings.advancedDnsZoneOrigin),
        'example.test.',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, strings.advancedDnsTtl),
        '60',
      );
      await submitDialog(tester);

      expect(controller.dnsZones.value, hasLength(1));
      expect(controller.dnsZones.value.single.origin, 'example.test.');
      expect(controller.dnsZones.value.single.ttl, 60);
      expect(find.text('example.test.'), findsOneWidget);
      expect(find.text(strings.advancedDnsNoRecords), findsOneWidget);

      // Add an A record, verifying IPv4 validation first.
      await tapSaving(tester, find.byTooltip(strings.advancedDnsAddRecord));
      await tester.enterText(
        find.widgetWithText(TextFormField, strings.advancedDnsRecordName),
        'nas',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, strings.advancedDnsRecordValue),
        'not-an-ip',
      );
      await tester.tap(find.text(strings.commonSave));
      await tester.pumpAndSettle();
      expect(find.text(strings.validationDnsRecordIpv4), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, strings.advancedDnsRecordValue),
        '10.0.0.8',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, strings.advancedDnsTtl),
        '120',
      );
      await submitDialog(tester);

      var zone = controller.dnsZones.value.single;
      expect(zone.records, hasLength(1));
      expect(zone.records.single.name, 'nas');
      expect(zone.records.single.type, DnsRecordType.a);
      expect(zone.records.single.value, '10.0.0.8');
      expect(zone.records.single.ttl, 120);
      expect(find.text('nas'), findsOneWidget);

      // Edit the record: switch type to TXT and change value.
      await tapSaving(tester, find.text('nas'));
      await tester.tap(find.text(strings.advancedDnsRecordType));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('TXT').last);
      await tester.enterText(
        find.widgetWithText(TextFormField, strings.advancedDnsRecordValue),
        '"local records"',
      );
      await submitDialog(tester);

      zone = controller.dnsZones.value.single;
      expect(zone.records.single.type, DnsRecordType.txt);
      expect(zone.records.single.value, '"local records"');

      // Delete the record.
      await tapSaving(tester, find.byTooltip(strings.advancedDnsDeleteRecord));
      expect(controller.dnsZones.value.single.records, isEmpty);
      expect(find.text(strings.advancedDnsNoRecords), findsOneWidget);

      // Edit zone origin and delete zone.
      await tapSaving(tester, find.byTooltip(strings.advancedDnsEditZone));
      await tester.enterText(
        find.widgetWithText(TextFormField, strings.advancedDnsZoneOrigin),
        'corp.test.',
      );
      await submitDialog(tester);
      expect(controller.dnsZones.value.single.origin, 'corp.test.');

      await tapSaving(tester, find.byTooltip(strings.advancedDnsDeleteZone));
      expect(controller.dnsZones.value, isEmpty);
      expect(find.text(strings.advancedDnsNoZones), findsOneWidget);
    },
  );
}
