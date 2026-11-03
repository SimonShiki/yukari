import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yukari_core/backend/privilege_windows.dart';
import 'package:yukari_core/backend/system/systemd_service.dart';

void main() {
  test('systemd unit quotes and escapes the command line', () {
    final unit = SystemdService.unit('/opt/Yukari App/bin/yukari-service', [
      'run',
      '--data-dir',
      r'/home/u/100%"$x\y',
    ]);
    expect(
      unit,
      contains(
        r'ExecStart="/opt/Yukari App/bin/yukari-service" "run" "--data-dir" '
        r'"/home/u/100%%\"$$x\\y"',
      ),
    );
    expect(unit, contains('RuntimeDirectory=yukari'));
    expect(unit, contains('WantedBy=multi-user.target'));
  });

  test('systemd unit keeps root to what EasyTier needs', () {
    final unit = SystemdService.unit('/opt/yukari/service/bin/s', ['run']);

    // Each is a decision: dropping one hands root back to the service.
    for (final line in [
      'NoNewPrivileges=yes',
      'ProtectSystem=strict',
      'ProtectHome=read-only',
      'DevicePolicy=closed',
      'DeviceAllow=/dev/net/tun rw',
      'UMask=0077',
    ]) {
      expect(unit, contains('$line\n'), reason: line);
    }
    final capabilities = RegExp(
      r'^CapabilityBoundingSet=(.*)$',
      multiLine: true,
    ).firstMatch(unit)!.group(1)!.split(' ');
    expect(capabilities, contains('CAP_NET_ADMIN'));
    expect(capabilities, isNot(contains('CAP_DAC_OVERRIDE')));
    expect(capabilities, isNot(contains('CAP_SETUID')));
  });

  test('systemd unit registers the copy, not the app', () {
    expect(SystemdService.defaultRoot, '/opt/yukari/service');
  });

  group('Linux staging', () {
    late Directory directory;
    late File executable;
    late SystemdService service;

    /// Lays out the app bundle, with [libraries] in its `lib`.
    void bundle(List<String> libraries) {
      final app = p.join(directory.path, 'app');
      executable = File(p.join(app, 'bin', 'yukari-service'))
        ..createSync(recursive: true)
        ..writeAsStringSync('service');
      // A build anyone could write, whose modes must not carry over.
      Process.runSync('chmod', ['777', executable.path]);
      for (final name in libraries) {
        File(p.join(app, 'lib', name))
          ..createSync(recursive: true)
          ..writeAsStringSync(name);
      }
    }

    List<String> stagedLibraries() => [
      for (final entry in Directory(p.join(service.root, 'lib')).listSync())
        p.basename(entry.path),
    ];

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('yukari_stage');
      addTearDown(() => directory.delete(recursive: true));
      service = SystemdService(root: p.join(directory.path, 'service'));
    });

    test('copies the service where no one else may write it', () async {
      bundle(['libeasytier_ffi.so', 'libflutter_linux_gtk.so']);

      final staged = await service.prepare(executable.path);

      expect(staged, p.join(service.root, 'bin', 'yukari-service'));
      expect(File(staged).readAsStringSync(), 'service');
      expect(File(staged).statSync().mode & 0x1FF, 0x1ED /* 0755 */);
      expect(stagedLibraries(), ['libeasytier_ffi.so']);
    });

    test('copies the library a release build downloaded', () async {
      // Release builds bundle the prebuilt library under its asset name.
      bundle(['linux-x86_64-libeasytier_ffi.so', 'libapp.so']);

      await service.prepare(executable.path);

      expect(stagedLibraries(), ['linux-x86_64-libeasytier_ffi.so']);
    });

    test('fails rather than staging a service without its library', () async {
      bundle(['libapp.so']);

      await expectLater(
        service.prepare(executable.path),
        throwsA(isA<FileSystemException>()),
      );
    });
  }, skip: Platform.isLinux ? false : 'systemd and umask are Linux only');

  test('Windows arguments survive CommandLineToArgvW', () {
    expect(quoteArgument('run'), 'run');
    expect(quoteArgument(''), '""');
    expect(quoteArgument(r'C:\Users\A B\AppData'), r'"C:\Users\A B\AppData"');
    expect(quoteArgument(r'C:\dir with space\'), r'"C:\dir with space\\"');
    expect(quoteArgument(r'say "hi"'), r'"say \"hi\""');
    expect(quoteArgument(r'a\"b'), r'"a\\\"b"');
  });
}
