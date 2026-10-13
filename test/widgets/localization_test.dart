import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/models/instance.dart';
import 'package:yukari/signals/locale.dart';
import 'package:yukari/utils/validator.dart';
import 'package:yukari/widgets/navigation/app_shell.dart';
import 'package:yukari/widgets/network_card/network_card.dart';

void main() {
  testWidgets('switches navigation, network status, and validation live', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setPreferredLocale(const Locale('en'));
    addTearDown(() => setPreferredLocale(null));
    await tester.pumpWidget(
      SignalBuilder(
        builder: (context) => MaterialApp(
          locale: appLocale.value,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: AppShell(
            currentIndex: 0,
            child: Center(
              child: NetworkCard(
                name: 'alpha',
                running: true,
                status: InstanceStatus.running,
                onToggle: (_) {},
                menuButton: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(validateNetworkName('', []), 'Network name cannot be empty');

    await setPreferredLocale(const Locale('zh'));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('运行中'), findsOneWidget);
    expect(find.byTooltip('停止 alpha'), findsOneWidget);
    expect(validateNetworkName('', []), '网络名称不能为空');
    expect(find.text('Settings'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
