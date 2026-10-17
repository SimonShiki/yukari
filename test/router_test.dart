import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/about/about_page.dart';
import 'package:yukari/router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => appRouter.go('/'));

  testWidgets('the About route deep-links into the shell', (tester) async {
    // Applying the location before the first build keeps the home dashboard
    // (and its backend probing) out of the test.
    appRouter.go('/about');
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: appRouter,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Source code'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);
  });
}
