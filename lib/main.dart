import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'utils/theme_provider.dart' as theme_provider;
import 'router.dart';

import 'signals/networks.dart' as networks;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persistent data before running
  await networks.init();

  runApp(const Yukari());
}

class Yukari extends StatelessWidget {
  const Yukari({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            return MaterialApp.router(
              title: 'Yukari',
              theme: theme_provider.getLightTheme(lightDynamic),
              darkTheme: theme_provider.getDarkTheme(darkDynamic),
              themeMode: theme_provider.themeMode.value,
              routerConfig: appRouter,
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}
