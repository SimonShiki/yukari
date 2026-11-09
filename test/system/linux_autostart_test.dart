@TestOn('linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yukari/system/linux_autostart.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('yukari-autostart-');
    addTearDown(() => directory.deleteSync(recursive: true));
  });

  File entryAt(String configHome) =>
      File(p.join(configHome, 'autostart', 'yukari.desktop'));

  final execCases = <String, String>{
    '/opt/Yukari App/yukari': 'Exec="/opt/Yukari App/yukari"',
    '/opt/yukari"name': r'Exec="/opt/yukari\\"name"',
    r'/opt/yukari\name': r'Exec="/opt/yukari\\\\name"',
    r'/opt/$HOME/yukari': r'Exec="/opt/\\$HOME/yukari"',
    '/opt/`name`/yukari': r'Exec="/opt/\\`name\\`/yukari"',
    '/opt/%f/%U/100%/yukari': 'Exec="/opt/%%f/%%U/100%%/yukari"',
    '/opt/yukari\nHidden': r'Exec="/opt/yukari\nHidden"',
    '/opt/yukari\rname': r'Exec="/opt/yukari\rname"',
    '/opt/yukari\tname': r'Exec="/opt/yukari\tname"',
    '/opt/雪/yukari': 'Exec="/opt/雪/yukari"',
  };
  for (final (index, entry) in execCases.entries.indexed) {
    test(
      'encodes executable path case $index as a single Exec value',
      () async {
        final autostart = LinuxAutostart(
          environment: {'XDG_CONFIG_HOME': directory.path},
          executable: entry.key,
        );
        await autostart.setEnabled(true);

        expect(await entryAt(directory.path).readAsLines(), [
          '[Desktop Entry]',
          'Type=Application',
          'Name=Yukari',
          entry.value,
          'Terminal=false',
          'X-GNOME-Autostart-enabled=true',
        ]);
      },
    );
  }

  test('prefers an absolute XDG directory over HOME', () async {
    final config = p.join(directory.path, 'xdg');
    final home = p.join(directory.path, 'home');
    final autostart = LinuxAutostart(
      environment: {'XDG_CONFIG_HOME': config, 'HOME': home},
    );
    expect(autostart.supported, isTrue);
    await autostart.setEnabled(true);
    expect(await entryAt(config).exists(), isTrue);
    expect(await Directory(home).exists(), isFalse);

    await autostart.setEnabled(false);
    await autostart.setEnabled(false);
    expect(await entryAt(config).exists(), isFalse);
  });

  for (final xdg in [null, '', 'relative/config']) {
    test('falls back to HOME for XDG_CONFIG_HOME=$xdg', () async {
      final autostart = LinuxAutostart(
        environment: {'HOME': directory.path, 'XDG_CONFIG_HOME': ?xdg},
      );
      expect(autostart.supported, isTrue);
      await autostart.setEnabled(true);
      expect(await entryAt(p.join(directory.path, '.config')).exists(), isTrue);
    });
  }

  for (final home in [null, '', 'relative/home']) {
    test(
      'does not resolve invalid directories against CWD: HOME=$home',
      () async {
        final relativeConfig = p.relative(directory.path);
        final autostart = LinuxAutostart(
          environment: {'XDG_CONFIG_HOME': relativeConfig, 'HOME': ?home},
        );
        expect(autostart.supported, isFalse);
        await autostart.setEnabled(true);
        await autostart.setEnabled(false);
        expect(await directory.list().toList(), isEmpty);
      },
    );
  }
}
