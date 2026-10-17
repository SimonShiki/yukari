import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yukari/signals/locale.dart';
import 'package:yukari/signals/settings.dart';
import 'package:yukari/system/autostart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initSettings(autostart: const UnsupportedAutostart());
    initLocale();
  });
  tearDown(() {
    settings.interface.setLocale(null);
    dispatcher.clearLocalesTestValue();
  });

  test('follows the system language', () {
    dispatcher.localesTestValue = const [Locale('zh', 'CN')];
    expect(appLocale.value, const Locale('zh'));
    expect(l10n.value.navSettings, '设置');
  });

  test('falls back to English for an unsupported system language', () {
    dispatcher.localesTestValue = const [Locale('fr', 'FR')];
    expect(appLocale.value, const Locale('en'));
  });

  test('keeps the picked language across launches', () async {
    dispatcher.localesTestValue = const [Locale('en', 'US')];
    settings.interface.setLocale(const Locale('zh'));
    expect(appLocale.value, const Locale('zh'));

    await initSettings(autostart: const UnsupportedAutostart());
    expect(settings.interface.locale.value, const Locale('zh'));
    expect(appLocale.value, const Locale('zh'));

    settings.interface.setLocale(null);
    await initSettings(autostart: const UnsupportedAutostart());
    expect(settings.interface.locale.value, isNull);
    expect(appLocale.value, const Locale('en'));
  });

  test('ignores a saved language the app no longer has', () async {
    SharedPreferences.setMockInitialValues({'locale': 'xx'});
    await initSettings(autostart: const UnsupportedAutostart());
    expect(settings.interface.locale.value, isNull);
  });
}
