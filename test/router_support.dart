import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/router.dart';

/// Pumps the app in a phone-sized window, settled.
///
/// Without [home] the app's own router is pumped; with it, [home] is the only
/// page. [theme] and [size] frame the app as the platform and window would,
/// and its brightness is pinned to light so the previews stay stable.
Future<void> pumpApp(
  WidgetTester tester, {
  Widget? home,
  ThemeData? theme,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  const delegates = [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ];
  final Widget app = home == null
      ? MaterialApp.router(
          theme: theme,
          localizationsDelegates: delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: appRouter,
        )
      : MaterialApp(
          theme: theme,
          localizationsDelegates: delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}
