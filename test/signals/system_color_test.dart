import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/signals/system_color.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => updateSystemColorSchemes());

  test('default to null and follow the platform schemes', () {
    expect(systemLightColorScheme.value, isNull);
    expect(systemDarkColorScheme.value, isNull);

    final light = ColorScheme.fromSeed(seedColor: Colors.teal);
    final dark = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );
    updateSystemColorSchemes(light: light, dark: dark);

    expect(systemLightColorScheme.value, light);
    expect(systemDarkColorScheme.value, dark);

    updateSystemColorSchemes();
    expect(systemLightColorScheme.value, isNull);
    expect(systemDarkColorScheme.value, isNull);
  });
}
