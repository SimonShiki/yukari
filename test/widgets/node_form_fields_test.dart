import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/widgets/node_form/node_form_fields.dart';
import 'package:yukari_core/models/node.dart';

void main() {
  Future<GlobalKey<NodeFormFieldsState>> pump(
    WidgetTester tester, {
    Node? node,
  }) async {
    final key = GlobalKey<NodeFormFieldsState>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NodeFormFields(key: key, initialNode: node),
        ),
      ),
    );
    return key;
  }

  testWidgets('creates a connection from three fields and keeps its full URL', (
    tester,
  ) async {
    final key = await pump(tester);
    expect(find.byType(TextFormField), findsNWidgets(3));
    await tester.enterText(
      find.widgetWithText(TextField, 'Peer name'),
      ' Local ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'URL'),
      'http://localhost:11451/ws?route=one',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Public Key (Optional)'),
      ' pin ',
    );
    final node = key.currentState!.validate()!;
    expect(node.name, 'Local');
    expect(node.url.toString(), 'http://localhost:11451/ws?route=one');
    expect(node.publicKey, 'pin');
  });

  testWidgets('editing keeps the URL path, query and public key', (
    tester,
  ) async {
    final original = Node(
      name: 'Relay',
      url: Uri.parse('wss://[::1]/ws?route=two'),
      publicKey: 'key',
    );
    final key = await pump(tester, node: original);
    expect(key.currentState!.validate()!.toJson(), original.toJson());
    await tester.enterText(
      find.widgetWithText(TextField, 'Public Key (Optional)'),
      '',
    );
    expect(key.currentState!.validate()!.publicKey, isNull);
    expect(original.publicKey, 'key');
  });
}
