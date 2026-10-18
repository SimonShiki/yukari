import 'dart:io';

import 'package:yukari_core/system/magic_dns.dart';
import 'package:yukari_core/system/system_command.dart';

/// Stands in for the OS: answers commands from [runHandler], and records what
/// ran, elevated or not.
final class FakeSystemCommand implements SystemCommand {
  FakeSystemCommand({this.runHandler, this.elevateHandler});

  /// Answers one command; null throws [ProcessException], as a missing
  /// executable does.
  final CommandResult? Function(String executable, List<String> arguments)?
  runHandler;

  /// Runs one elevated command; throwing stands in for a failed elevation.
  final Future<void> Function(String executable, List<String> arguments)?
  elevateHandler;

  final runs = <(String, List<String>)>[];
  final elevated = <(String, List<String>)>[];

  @override
  Future<CommandResult> run(String executable, List<String> arguments) async {
    runs.add((executable, arguments));
    final handler = runHandler;
    if (handler == null) {
      throw ProcessException(executable, arguments, 'not found', 127);
    }
    final result = handler(executable, arguments);
    if (result == null) {
      throw ProcessException(executable, arguments, 'not found', 127);
    }
    return result;
  }

  @override
  Future<void> runElevated(String executable, List<String> arguments) async {
    elevated.add((executable, arguments));
    await elevateHandler?.call(executable, arguments);
  }
}

/// A command that succeeded with [stdout].
CommandResult ok([String stdout = '']) => (exitCode: 0, stdout: stdout);

/// A command that failed.
CommandResult failed() => (exitCode: 1, stdout: '');

/// A Linux host where the route to the Magic DNS server leaves through
/// [interface], and `resolvectl` reports whatever [configured] says at the
/// time it is asked.
CommandResult? Function(String, List<String>) linuxHost({
  String interface = 'et_12_xoih',
  bool Function()? configured,
  bool resolvectl = true,
}) => (executable, arguments) {
  final isUp = configured?.call() ?? false;
  if (executable == 'ip' && arguments.first == '-4') {
    return ok('100.100.100.101 dev $interface src 10.126.126.2 uid 1000');
  }
  if (executable != 'resolvectl') return null;
  if (!resolvectl) {
    throw ProcessException(executable, arguments, 'not found', 127);
  }
  if (arguments.first == 'dns') {
    return ok(
      isUp ? 'Link 4 ($interface): 100.100.100.101' : 'Link 4 ($interface):',
    );
  }
  if (arguments.first == 'domain') {
    return ok(isUp ? 'Link 4 ($interface): ~et.net' : 'Link 4 ($interface):');
  }
  return null;
};

/// The Magic DNS system of a Linux host driven by [command].
MagicDnsSystem linuxSystem(FakeSystemCommand command) =>
    MagicDnsSystem(platform: MagicDnsPlatform.linux, command: command);

/// The Magic DNS system of a Windows host driven by [command].
MagicDnsSystem windowsSystem(FakeSystemCommand command) =>
    MagicDnsSystem(platform: MagicDnsPlatform.windows, command: command);

/// The Magic DNS system of the Android root service driven by [command].
MagicDnsSystem androidSystem(FakeSystemCommand command) =>
    MagicDnsSystem(platform: MagicDnsPlatform.android, command: command);

/// An Android host where the route to the Magic DNS server leaves through
/// [interface], whose `iptables`, when it exists at all, can load the matches
/// when [matches] says so, where the zone's rule is installed when
/// [configured] says so and the jump from OUTPUT is there when [jump] does,
/// and whose resolver file holds [resolvConf].
CommandResult? Function(String, List<String>) androidHost({
  String interface = 'et_12_xoih',
  bool Function()? configured,
  bool Function()? jump,
  bool iptables = true,
  bool matches = true,
  String resolvConf = '',
}) => (executable, arguments) {
  if (executable == 'cat') return ok(resolvConf);
  if (executable == 'ip' && arguments.first == '-4') {
    return ok('100.100.100.101 dev $interface src 10.126.126.2 uid 0');
  }
  if (executable != 'iptables') return null;
  if (!iptables) {
    throw ProcessException(executable, arguments, 'not found', 127);
  }
  if (arguments.contains('--help')) return matches ? ok('') : failed();
  if (arguments.contains('-C')) {
    final present = arguments[3] == 'OUTPUT'
        ? (jump?.call() ?? false)
        : (configured?.call() ?? false);
    return present ? ok('') : failed();
  }
  return ok('');
};
