import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'l10n/l10n.dart';
import 'signals/locale.dart';
import 'signals/settings.dart';
import 'signals/system_color.dart';
import 'router.dart';

import 'signals/backend.dart';
import 'signals/bookmarks.dart' as bookmarks;
import 'signals/networks.dart' as networks;
import 'storage/bookmark_store.dart';
import 'storage/network_store.dart';
import 'utils/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persistent data before running. The service reads the same store.
  final dataDir = (await getApplicationSupportDirectory()).path;
  await networks.init(NetworkStore.inDirectory(dataDir));
  await bookmarks.init(BookmarkStore.inDirectory(dataDir));
  await initSettings();
  await initBackend(dataDir);
  initLocale();

  runApp(const Yukari());
}

class Yukari extends StatelessWidget {
  const Yukari({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // The theming page previews the platform schemes from these signals;
        // reporting them after the frame avoids writing signals during build.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) =>
              updateSystemColorSchemes(light: lightDynamic, dark: darkDynamic),
        );
        return SignalBuilder(
          builder: (context) {
            final theme = settings.theme;
            final mode = theme.mode.value;
            final palette = theme.palette.value;
            final variant = theme.variant.value;
            final useSystemColor = theme.useSystemColor.value;
            ThemeData appTheme(Brightness brightness, ColorScheme? scheme) =>
                buildTheme(
                  brightness: brightness,
                  mode: mode,
                  palette: palette,
                  variant: variant,
                  useSystemColor: useSystemColor,
                  systemScheme: scheme,
                );
            return MaterialApp.router(
              title: 'Yukari',
              theme: appTheme(Brightness.light, lightDynamic),
              darkTheme: appTheme(Brightness.dark, darkDynamic),
              themeMode: themeModeFor(mode),
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
