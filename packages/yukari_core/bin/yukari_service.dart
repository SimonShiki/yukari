import 'dart:io';

import 'package:yukari_core/daemon/service_cli.dart';

/// The background service that runs networks with full privileges.
///
/// Built by `dart build cli` and bundled in the app's `bin/` directory.
Future<void> main(List<String> arguments) async {
  final code = await runServiceCli(arguments);
  await Future.wait([stdout.flush(), stderr.flush()]);
  exit(code);
}
