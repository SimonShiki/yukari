import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yukari/signals/locale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocale();
  });
  tearDown(dispatcher.clearLocalesTestValue);

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
    await setPreferredLocale(const Locale('zh'));
    expect(appLocale.value, const Locale('zh'));

    await initLocale();
    expect(preferredLocale.value, const Locale('zh'));

    await setPreferredLocale(null);
    await initLocale();
    expect(preferredLocale.value, isNull);
    expect(appLocale.value, const Locale('en'));
  });

  test('ignores a saved language the app no longer has', () async {
    SharedPreferences.setMockInitialValues({'locale': 'xx'});
    await initLocale();
    expect(preferredLocale.value, isNull);
  });
}
