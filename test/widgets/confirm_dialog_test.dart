import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/widgets/dialog/confirm_dialog.dart';

void main() {
  /// Pumps a page whose only button asks through [onAsk].
  Future<void> pumpHost(
    WidgetTester tester,
    Future<void> Function(BuildContext context) onAsk,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => onAsk(context),
            child: const Text('ask'),
          ),
        ),
      ),
    );
  }

  Future<void> ask(WidgetTester tester) async {
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
  }

  Future<void> askPlain(WidgetTester tester, void Function(bool) answer) =>
      pumpHost(tester, (context) async {
        answer(
          await showConfirmDialog(
            context,
            icon: Icons.warning_amber_rounded,
            title: 'Discard?',
            message: 'The edits will be lost.',
            confirmLabel: 'Discard',
          ),
        );
      });

  testWidgets('answers no when dismissed, and no on cancel', (tester) async {
    bool? answer;
    await askPlain(tester, (value) => answer = value);

    await ask(tester);
    // A tap outside the dialog dismisses it, which means no.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    await ask(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });

  testWidgets('answers yes on the confirm button', (tester) async {
    bool? answer;
    await askPlain(tester, (value) => answer = value);

    await ask(tester);
    expect(find.widgetWithText(FilledButton, 'Discard'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('replaces the cancel label when one is given', (tester) async {
    bool? answer;
    await pumpHost(tester, (context) async {
      answer = await showConfirmDialog(
        context,
        icon: Icons.warning_amber_rounded,
        title: 'Discard?',
        message: 'The edits will be lost.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
      );
    });

    await ask(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });

  testWidgets('a destructive confirm carries the error colours', (
    tester,
  ) async {
    await pumpHost(
      tester,
      (context) => showConfirmDialog(
        context,
        icon: Icons.delete_outline,
        title: 'Delete?',
        message: 'This cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true,
      ),
    );

    await ask(tester);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    final scheme = Theme.of(tester.element(find.text('Delete'))).colorScheme;
    expect(button.style?.backgroundColor?.resolve({}), scheme.error);
    expect(button.style?.foregroundColor?.resolve({}), scheme.onError);
  });
}
