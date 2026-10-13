import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/backend.dart';
import '../privilege.dart';
import 'service_control.dart';

/// Controls the service on Android, where a KernelSU or Magisk module runs it
/// as root; see `tool/service_module/`. Every command goes through `su`.
final class ModuleServiceControl implements ServiceControl {
  ModuleServiceControl({required this.dataDir});

  /// The module id, which names its directory under /data/adb/modules.
  static const id = 'yukari_service';

  /// The latest module, which `.github/workflows/service-module.yml` builds.
  static final release = Uri.parse(
    'https://github.com/SimonShiki/yukari/releases/download/'
    'ksu-service-module/yukari-service-module.zip',
  );

  /// Defines `module COMMAND`, which runs `yukari.sh` from the newest copy of
  /// the module: one installed since the last reboot waits in
  /// modules_update, yet runs fine from there.
  static const _prelude =
      '''
module() {
  for dir in /data/adb/modules_update/$id /data/adb/modules/$id; do
    if [ -f "\$dir/yukari.sh" ] && [ ! -f "\$dir/remove" ]; then
      sh "\$dir/yukari.sh" "\$@"
      return
    fi
  done
  echo notInstalled
}
''';

  @override
  final String dataDir;

  /// Root may be granted at any time, which [state] reports.
  @override
  bool get supported => true;

  @override
  Future<ServiceState> state() async {
    final String output;
    try {
      output = await _su('module status');
    } on _RootDenied {
      return ServiceState.rootRequired;
    }
    return ServiceState.values.asNameMap()[output.trim()] ??
        (throw ElevationException('Unexpected module status: $output'));
  }

  /// Downloads the latest module, installs it and starts it, replacing the
  /// running version.
  @override
  Future<void> install({void Function(double? progress)? onProgress}) async {
    final zip = File(
      p.join((await getTemporaryDirectory()).path, release.pathSegments.last),
    );
    await _download(zip, onProgress);
    onProgress?.call(null);
    await _su('''
zip=${_quote(zip.path)}
if [ -x /data/adb/ksud ]; then
  /data/adb/ksud module install "\$zip"
elif command -v magisk >/dev/null; then
  magisk --install-module "\$zip"
else
  echo "Neither KernelSU nor Magisk was found" >&2
  false
fi
status=\$?
rm -f "\$zip"
[ \$status = 0 ] || exit \$status
module stop
module start
''');
  }

  /// Stops the service and has the module removed on the next reboot.
  @override
  Future<void> uninstall() => _su('''
module stop
rm -rf /data/adb/modules_update/$id
if [ -d /data/adb/modules/$id ]; then touch /data/adb/modules/$id/remove; fi
''');

  @override
  Future<void> start() => _su('module start');

  @override
  Future<void> stop() => _su('module stop');

  /// Downloads [release] into [file], reporting progress to [onProgress].
  static Future<void> _download(
    File file,
    void Function(double? progress)? onProgress,
  ) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(release)).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Could not download the module: HTTP ${response.statusCode}',
          uri: release,
        );
      }
      final total = response.contentLength;
      var received = 0;
      final sink = file.openWrite();
      try {
        await sink.addStream(
          response.map((chunk) {
            received += chunk.length;
            onProgress?.call(total > 0 ? received / total : null);
            return chunk;
          }),
        );
      } finally {
        await sink.close();
      }
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  /// Runs [script] as root after [_prelude] and returns what it printed.
  ///
  /// Throws [_RootDenied] when `su` is missing or refuses, and
  /// [ElevationException] when [script] fails.
  static Future<String> _su(String script) async {
    const granted = 'yukari: root granted';
    final Process process;
    try {
      process = await Process.start('su', const []);
    } on ProcessException {
      throw const _RootDenied();
    }
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.write('echo "$granted"\n$_prelude$script\n');
    // su closes its input at once when it refuses.
    await process.stdin.close().catchError((Object _) {});
    final code = await process.exitCode;
    // A process left behind with su's output open would keep it from ending.
    final printed = await output.timeout(
      const Duration(seconds: 5),
      onTimeout: () =>
          throw const ElevationException('A root command left its output open'),
    );
    if (!printed.startsWith('$granted\n')) throw const _RootDenied();
    if (code == 0) return printed.substring(granted.length + 1);
    final error = (await errors.timeout(
      const Duration(seconds: 1),
      onTimeout: () => '',
    )).trim();
    throw ElevationException(
      error.isNotEmpty ? error : 'Root command failed with code $code',
    );
  }

  static String _quote(String value) => "'${value.replaceAll("'", r"'\''")}'";
}

final class _RootDenied implements Exception {
  const _RootDenied();

  @override
  String toString() => 'Yukari has not been granted root access';
}
