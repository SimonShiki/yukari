import 'dart:io';

import 'package:yukari_core/system/magic_dns.dart';
import 'package:yukari_core/system/system_command.dart';

/// Stands in for the OS: answers commands from [runHandler], and records what
/// ran.
final class FakeSystemCommand implements SystemCommand {
  FakeSystemCommand({this.runHandler});

  /// Answers one command; null throws [ProcessException], as a missing
  /// executable does.
  final CommandResult? Function(String executable, List<String> arguments)?
  runHandler;

  final runs = <(String, List<String>)>[];

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
}

/// A command that succeeded with [stdout].
CommandResult ok([String stdout = '']) => (exitCode: 0, stdout: stdout);

/// A command that failed.
CommandResult failed() => (exitCode: 1, stdout: '');

/// What `ip` reports on a host whose [links] map each interface to its IPv4
/// (empty where an interface has none), and where [decoy] owns the route to the
/// Magic DNS server.
///
/// A local address answers from the local table, as it does on a real host:
/// that route names `lo`, never the link that owns the address.
CommandResult? _ip(
  List<String> arguments,
  Map<String, String> links,
  String decoy,
) {
  if (arguments case ['link', 'show', final name]) {
    return links.containsKey(name)
        ? ok('$name: <POINTOPOINT,UP,LOWER_UP>')
        : failed();
  }
  if (arguments case ['-4', '-o', 'addr', 'show', 'to', final host]) {
    for (final MapEntry(:key, :value) in links.entries) {
      if (value.split('/').first == host) {
        return ok('33: $key    inet $value scope global $key');
      }
    }
    return ok('');
  }
  if (arguments case ['-4', 'route', 'get', final host]) {
    return host == magicDnsServer
        ? ok('$host dev $decoy src 198.18.0.1 uid 1000')
        : ok('local $host dev lo table local src $host');
  }
  return null;
}

/// The Magic DNS system of the Android root service driven by [command].
MagicDnsSystem androidSystem(FakeSystemCommand command) =>
    MagicDnsSystem(platform: MagicDnsPlatform.android, command: command);

/// An Android host where the EasyTier TUN is [interface] holding [address],
/// where `iptables`, when it exists at all, can load the matches when [matches]
/// says so, where the zone's rule is installed when [configured] says so, where
/// the jump from OUTPUT is there when [jump] does, and where the resolver file
/// holds [resolvConf].
CommandResult? Function(String, List<String>) androidHost({
  String interface = 'et_12_xoih',
  String address = '10.126.126.2/24',
  bool Function()? configured,
  bool Function()? jump,
  bool iptables = true,
  bool matches = true,
  String resolvConf = '',
}) => (executable, arguments) {
  if (executable == 'cat') return ok(resolvConf);
  if (executable == 'ip') {
    return _ip(arguments, {interface: address}, interface);
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
