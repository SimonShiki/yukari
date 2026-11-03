import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yukari/signals/settings.dart';

import '../async_support.dart';
import '../fake_autostart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('applies start on boot on load and as it changes', () async {
    final autostart = FakeAutostart();
    await initSettings(autostart: autostart);

    expect(autostart.applied, [false]);
    settings.behavior.setStartOnBoot(true);
    await waitFor(() => autostart.applied.length == 2);

    expect(autostart.applied, [false, true]);
  });

  test('reports whether the OS supports starting on boot', () async {
    await initSettings(autostart: FakeAutostart(supported: false));
    expect(settings.behavior.startOnBootSupported, isFalse);

    await initSettings(autostart: FakeAutostart());
    expect(settings.behavior.startOnBootSupported, isTrue);
  });

  test('starts with start on boot off when the OS refuses it', () async {
    SharedPreferences.setMockInitialValues({'behavior.startOnBoot': true});
    final autostart = FakeAutostart(refuse: true);

    await initSettings(autostart: autostart);

    expect(settings.behavior.startOnBoot.value, isFalse);
    expect(autostart.attempts, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('behavior.startOnBoot'), isFalse);
  });

  test('turns start on boot back off when the OS refuses it', () async {
    final autostart = FakeAutostart(refuse: true);
    await initSettings(autostart: autostart);
    expect(autostart.attempts, 1, reason: 'loading applies the default');

    settings.behavior.setStartOnBoot(true);
    await waitFor(
      () => autostart.attempts == 2 && !settings.behavior.startOnBoot.value,
    );
    await pumpEventQueue();

    expect(settings.behavior.startOnBoot.value, isFalse);
    expect(autostart.attempts, 2, reason: 'the refused change is not retried');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('behavior.startOnBoot'), isFalse);
  });

  test('the last start on boot toggle wins when applies overlap', () async {
    final autostart = FakeAutostart();
    await initSettings(autostart: autostart);
    expect(autostart.applied, [false]);
    autostart.enableGate = Completer<void>();

    settings.behavior.setStartOnBoot(true);
    expect(autostart.attempts, 2, reason: 'the enable is in flight');
    settings.behavior.setStartOnBoot(false);
    expect(autostart.applied, [false], reason: 'the disable waits its turn');

    autostart.enableGate!.complete();
    await waitFor(
      () => autostart.applied.length == 3 && autostart.state == false,
    );
    await pumpEventQueue();

    expect(
      autostart.applied,
      [false, true, false],
      reason: 'the applies do not overlap',
    );
    expect(settings.behavior.startOnBoot.value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('behavior.startOnBoot'), isFalse);
  });

  test('keeps start on boot on when the OS refuses to disable it', () async {
    final autostart = FakeAutostart();
    await initSettings(autostart: autostart);
    settings.behavior.setStartOnBoot(true);
    await waitFor(() => autostart.applied.length == 2);

    autostart.refuseDisable = true;
    settings.behavior.setStartOnBoot(false);
    await waitFor(
      () => autostart.attempts == 3 && settings.behavior.startOnBoot.value,
    );
    await pumpEventQueue();

    expect(settings.behavior.startOnBoot.value, isTrue);
    expect(autostart.applied, [false, true], reason: 'the disable was refused');
    expect(autostart.state, isTrue);
    expect(autostart.attempts, 3, reason: 'the revert is not retried');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('behavior.startOnBoot'), isTrue);
  });
}
