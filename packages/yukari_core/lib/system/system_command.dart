import 'dart:io';

import '../backend/privilege.dart' as privilege;

/// The exit code and output of one system command.
typedef CommandResult = ({int exitCode, String stdout});

/// Runs the system commands a feature needs, so tests can stand in for the OS.
abstract interface class SystemCommand {
  /// Runs [executable] with [arguments] as the current user.
  ///
  /// Throws [ProcessException] when the executable is missing.
  Future<CommandResult> run(String executable, List<String> arguments);

  /// Runs [executable] with [arguments] with administrator rights, asking the
  /// user to authorize when the process is not elevated already.
  ///
  /// Throws [ElevationException] when the user declines or the command fails.
  Future<void> runElevated(String executable, List<String> arguments);
}

/// The [SystemCommand] of the running system.
final class ProcessSystemCommand implements SystemCommand {
  const ProcessSystemCommand();

  @override
  Future<CommandResult> run(String executable, List<String> arguments) async {
    final result = await Process.run(executable, arguments);
    return (exitCode: result.exitCode, stdout: '${result.stdout}');
  }

  @override
  Future<void> runElevated(String executable, List<String> arguments) =>
      privilege.runElevated(executable, arguments);
}
