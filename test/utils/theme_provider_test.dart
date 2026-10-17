import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/utils/theme_provider.dart';

/// The font set the Windows theme must pin, in order.
const _windowsFallback = <String>[
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'Segoe UI Symbol',
];

void main() {
  group('theme fonts', () {
    test('pins the Windows font stack on every text style', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      for (final theme in [getLightTheme(null), getDarkTheme(null)]) {
        for (final style in [
          theme.textTheme.displayLarge,
          theme.textTheme.titleMedium,
          theme.textTheme.labelSmall,
          theme.textTheme.bodyMedium,
          theme.primaryTextTheme.bodyMedium,
        ]) {
          expect(style?.fontFamily, 'Segoe UI');
          expect(style?.fontFamilyFallback, _windowsFallback);
        }
      }
    });

    test("keeps Flutter's own fonts where Flutter already pins them", () {
      // flutter_test reports the host as Android, which Flutter pins itself.
      expect(defaultTargetPlatform, TargetPlatform.android);

      final theme = getLightTheme(null);

      expect(theme.textTheme.bodyMedium?.fontFamily, 'Roboto');
      expect(theme.textTheme.bodyMedium?.fontFamilyFallback, isNull);
    });

    testWidgets('the localized theme keeps the pinned stack for Chinese', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      // The binding verifies foundation debug variables before tearDowns run,
      // so the override is cleared here rather than in an addTearDown.
      try {
        TextTheme? localized;
        await tester.pumpWidget(
          MaterialApp(
            theme: getLightTheme(null),
            locale: const Locale('zh'),
            supportedLocales: const [Locale('zh')],
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Builder(
              builder: (context) {
                localized = Theme.of(context).textTheme;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(localized?.bodyMedium?.fontFamily, 'Segoe UI');
        expect(localized?.bodyMedium?.fontFamilyFallback, _windowsFallback);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
