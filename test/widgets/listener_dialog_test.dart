import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari/pages/networks/widgets/listener_dialog.dart';
import 'package:yukari/widgets/context_menu/m3e_menu_panel.dart';
import 'package:yukari/widgets/select_item/select_item.dart';

void main() {
  testWidgets('picks the listener protocol and saves it', (tester) async {
    Uri? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await showListenerDialog(context);
                },
                child: const Text('add'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    expect(find.text('Add Listener'), findsOneWidget);

    final select = find.byType(SelectItem<NodeProtocol>);
    expect(select, findsOneWidget);
    // The protocol picker sits on its own field surface, like host and port.
    final colors = Theme.of(tester.element(select)).colorScheme;
    expect(
      find.ancestor(
        of: select,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Material && widget.color == colors.surfaceContainer,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Protocol'));
    await tester.pumpAndSettle();
    expect(find.byType(M3EMenuPanel), findsOneWidget);
    await tester.tap(find.text('UDP'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: select, matching: find.text('UDP')),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.scheme, 'udp');
    expect(result!.host, '0.0.0.0');
    expect(result!.port, 11010);
  });
}
