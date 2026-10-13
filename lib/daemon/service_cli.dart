import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../backend/system/system_service.dart';
import 'service_runner.dart';

/// Runs the service command line and returns the exit code.
Future<int> runServiceCli(List<String> arguments) async {
  final runner =
      CommandRunner<void>(
          'yukari-service',
          'The Yukari background service, which runs networks with full '
              'privileges.',
        )
        ..addCommand(
          _Command(
            'run',
            'Run the service in the foreground, as the OS service manager does.',
            (command) => runService(
              dataDir: command.dataDir,
              ownerUid: command.ownerUid,
            ),
            servesNetworks: true,
          ),
        )
        ..addCommand(
          _Command(
            'install',
            'Register the service to start on boot, then start it.',
            (command) => _system.install(Platform.resolvedExecutable, [
              'run',
              '--data-dir',
              p.absolute(command.dataDir),
              if (command.ownerUid case final uid?) ...['--owner-uid', '$uid'],
            ]),
            servesNetworks: true,
          ),
        )
        ..addCommand(
          _Command(
            'uninstall',
            'Stop the service and remove its registration.',
            (_) => _system.uninstall(),
          ),
        )
        ..addCommand(
          _Command(
            'start',
            'Start the installed service.',
            (_) => _system.start(),
          ),
        )
        ..addCommand(
          _Command(
            'stop',
            'Stop the installed service.',
            (_) => _system.stop(),
          ),
        )
        ..addCommand(
          _Command(
            'status',
            'Print whether the service is installed and running.',
            (_) async => stdout.writeln((await _system.state()).name),
          ),
        );
  try {
    await runner.run(arguments);
    return 0;
  } on UsageException catch (error) {
    stderr.writeln(error);
    return 64;
  } catch (error) {
    stderr.writeln(error);
    return 1;
  }
}

final class _Command extends Command<void> {
  _Command(
    this.name,
    this.description,
    this._action, {
    bool servesNetworks = false,
  }) {
    if (!servesNetworks) return;
    argParser
      ..addOption(
        'data-dir',
        help: "Required. The app's data directory, holding networks.json.",
      )
      ..addOption(
        'owner-uid',
        help: 'The user allowed to control the service (Linux only).',
      );
  }

  @override
  final String name;

  @override
  final String description;

  final Future<void> Function(_Command command) _action;

  String get dataDir =>
      argResults!.option('data-dir') ?? usageException('Missing --data-dir');

  int? get ownerUid => switch (argResults!.option('owner-uid')) {
    null => null,
    final uid => int.tryParse(uid) ?? usageException('Bad --owner-uid: $uid'),
  };

  @override
  Future<void> run() => _action(this);
}

SystemService get _system =>
    SystemService.current ??
    (throw UnsupportedError('No supported service manager was found'));
