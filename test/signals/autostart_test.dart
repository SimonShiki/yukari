import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yukari/signals/settings.dart';
import 'package:yukari/system/linux_autostart.dart';

import '../async_support.dart';

/// The entry's text, or null while the file is missing or still being written.
String? _entryText(File entry) {
  try {
    return entry.existsSync() ? entry.readAsStringSync() : null;
  } on FileSystemException {
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('registers and removes the XDG autostart entry', () async {
    final configHome = Directory.systemTemp.createTempSync('yukari-autostart');
    addTearDown(() => configHome.deleteSync(recursive: true));
    final entry = File(p.join(configHome.path, 'autostart', 'yukari.desktop'));
    await initSettings(
      autostart: LinuxAutostart(
        configHome: configHome.path,
        executable: '/opt/yukari/yukari',
      ),
    );
    expect(entry.existsSync(), isFalse, reason: 'off by default');

    settings.behavior.setStartOnBoot(true);
    await waitFor(
      () => _entryText(entry)?.contains('Exec="/opt/yukari/yukari"') ?? false,
    );

    settings.behavior.setStartOnBoot(false);
    await waitFor(() => !entry.existsSync());
  });
}
