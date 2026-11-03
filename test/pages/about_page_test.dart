import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yukari/controllers/about_controller.dart';
import 'package:yukari/l10n/l10n.dart';
import 'package:yukari/pages/about/about_page.dart';
import 'package:yukari/widgets/link_list/link_list.dart';
import 'package:yukari/widgets/snackbar/app_snackbar.dart';

/// The app icon the About page must show, as declared in pubspec.
const _logoAsset = 'assets/generated/yukari-with-background-1024.png';

/// The repository the source-code link must open.
const _repository = 'https://github.com/SimonShiki/yukari';

/// What a pumped About page exposed while the test ran.
class _About {
  const _About({
    required this.controller,
    required this.messages,
    required this.launched,
  });

  final AboutController controller;

  /// Every message the controller reported, in order.
  final List<String> messages;

  /// Every URL the controller asked the launcher to open, in order.
  final List<Uri> launched;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps [AboutPage] with one controller whose dependencies the test owns.
  Future<_About> pumpAbout(
    WidgetTester tester, {
    Future<String?> Function()? appVersion,
    Future<bool> Function(Uri url)? launch,
  }) async {
    final messages = <String>[];
    final launched = <Uri>[];
    late BuildContext snackBarContext;
    final controller = AboutController(
      showMessage: (message) {
        messages.add(message);
        showAppSnackBar(snackBarContext, message);
      },
      appVersion: appVersion ?? () async => '1.2.3',
      launch: (url) {
        launched.add(url);
        return launch?.call(url) ?? Future.value(true);
      },
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            snackBarContext = context;
            return AboutPage(controller: controller);
          },
        ),
      ),
    );
    await tester.pump();
    return _About(
      controller: controller,
      messages: messages,
      launched: launched,
    );
  }

  testWidgets('shows the app icon, name and version', (tester) async {
    await pumpAbout(tester);

    final logo = tester.widget<Image>(find.byType(Image));
    expect(
      logo.image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'assetName',
        _logoAsset,
      ),
    );
    expect(tester.getSize(find.byType(Image)), const Size(96, 96));
    expect(find.text('Yukari'), findsOneWidget);
    expect(find.text('Version 1.2.3'), findsOneWidget);
  });

  testWidgets('omits the version when the platform reports none', (
    tester,
  ) async {
    await pumpAbout(tester, appVersion: () async => null);

    expect(find.text('Yukari'), findsOneWidget);
    expect(find.textContaining('Version'), findsNothing);
  });

  testWidgets('omits the version when the lookup fails', (tester) async {
    await pumpAbout(
      tester,
      appVersion: () async => throw StateError('no package info'),
    );

    expect(find.textContaining('Version'), findsNothing);
  });

  testWidgets('runs on its real dependencies and disposes them', (
    tester,
  ) async {
    // No injected controller: package_info_plus has no plugin under
    // `flutter test`, which the controller must swallow as "no version".
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AboutPage(),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Yukari'), findsOneWidget);
    expect(find.text('Source code'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);
    expect(find.textContaining('Version'), findsNothing);
    expect(tester.takeException(), isNull);

    // Leave the page as a popped route would, exercising the controller the
    // page created and owns.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('follows the version signal', (tester) async {
    final about = await pumpAbout(tester);

    about.controller.version.value = '2.0.0';
    await tester.pump();

    expect(find.text('Version 2.0.0'), findsOneWidget);
    expect(find.text('Version 1.2.3'), findsNothing);
  });

  testWidgets('shows the source and license links with their icons', (
    tester,
  ) async {
    await pumpAbout(tester);

    expect(find.text('Source code'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);
    expect(find.byIcon(Icons.code_rounded), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
  });

  testWidgets('opens the repository from anywhere on the source row', (
    tester,
  ) async {
    final about = await pumpAbout(tester);
    final label = tester.getRect(find.text('Source code'));

    // The label itself, then the row's trailing edge away from it.
    await tester.tapAt(label.center);
    await tester.pump();
    expect(about.launched, [Uri.parse(_repository)]);

    await tester.tapAt(Offset(label.right + 200, label.center.dy));
    await tester.pump();
    expect(about.launched, [Uri.parse(_repository), Uri.parse(_repository)]);
  });

  testWidgets('opens the built-in license page for this app', (tester) async {
    await pumpAbout(tester);

    await tester.tap(find.text('View licenses'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final page = tester.widget<LicensePage>(find.byType(LicensePage));
    expect(page.applicationName, 'Yukari');
    expect(page.applicationVersion, '1.2.3');
    expect(
      find.descendant(
        of: find.byType(LicensePage),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reports a launch failure in a snackbar', (tester) async {
    final about = await pumpAbout(tester, launch: (_) async => false);

    await tester.tap(find.text('Source code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    const message = 'Could not open the link: $_repository';
    expect(about.messages, [message]);
    expect(find.text(message), findsOneWidget);
  });

  testWidgets('pins the links to the bottom', (tester) async {
    await pumpAbout(tester);

    final page = tester.getRect(find.byType(Scaffold));
    final links = tester.getRect(find.byType(LinkList));
    expect(links.bottom, closeTo(page.bottom - 16, 0.1));
    expect(tester.getRect(find.byType(Image)).bottom, lessThan(links.top));
  });

  group('AboutController', () {
    AboutController controller({
      required List<String> messages,
      Future<String?> Function()? appVersion,
      Future<bool> Function(Uri url)? launch,
    }) => AboutController(
      showMessage: messages.add,
      appVersion: appVersion ?? () async => '1.2.3',
      launch: launch ?? (_) async => true,
    );

    test('reports a launcher that throws', () async {
      final messages = <String>[];
      final about = controller(
        messages: messages,
        launch: (_) async => throw StateError('no browser'),
      );
      addTearDown(about.dispose);

      await about.openSourceCode();

      expect(messages, ['Could not open the link: Bad state: no browser']);
    });

    test('survives being disposed while the version loads', () async {
      final version = Completer<String?>();
      final about = controller(messages: [], appVersion: () => version.future);
      final loading = about.loadVersion();

      about.dispose();
      version.complete('1.2.3');

      await expectLater(loading, completes);
    });
  });
}
