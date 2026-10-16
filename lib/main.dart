import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'l10n/l10n.dart';
import 'signals/locale.dart';
import 'utils/theme_provider.dart' as theme_provider;
import 'router.dart';

import 'signals/backend.dart';
import 'signals/bookmarks.dart' as bookmarks;
import 'signals/networks.dart' as networks;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dataDir = (await getApplicationSupportDirectory()).path;
  await networks.init(p.join(dataDir, 'networks'));
  await bookmarks.init(p.join(dataDir, 'bookmarks'));
  await initBackend(dataDir);
  await initLocale();

  runApp(const Yukari());
}

class Yukari extends StatelessWidget {
  const Yukari({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return SignalBuilder(
          builder: (context) {
            return MaterialApp.router(
              title: 'Yukari',
              theme: theme_provider.getLightTheme(lightDynamic),
              darkTheme: theme_provider.getDarkTheme(darkDynamic),
              themeMode: theme_provider.themeMode.value,
              locale: appLocale.value,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                // material_ui's own, which its widgets look up; not the
                // flutter_localizations ones AppLocalizations lists.
                ...GlobalMaterialLocalizations.delegates,
              ],
              routerConfig: appRouter,
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}
