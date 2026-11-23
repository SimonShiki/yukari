import 'dart:io';

/// The exit code and output of one system command.
typedef CommandResult = ({int exitCode, String stdout});

/// Runs the system commands a feature needs, so tests can stand in for the OS.
abstract interface class SystemCommand {
  /// Runs [executable] with [arguments] as the current user.
  ///
  /// Throws [ProcessException] when the executable is missing.
  Future<CommandResult> run(String executable, List<String> arguments);
}

/// The [SystemCommand] of the running system.
final class ProcessSystemCommand implements SystemCommand {
  const ProcessSystemCommand();

  @override
  Future<CommandResult> run(String executable, List<String> arguments) async {
    final result = await Process.run(executable, arguments);
    return (exitCode: result.exitCode, stdout: '${result.stdout}');
  }
}
