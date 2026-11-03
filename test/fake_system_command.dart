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

/// What `ip` reports on a host whose [links] map each interface to its IPv4
/// (empty when it has none), and where [decoy] owns the route to the Magic DNS
/// server.
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

/// A Linux host with one EasyTier TUN, [interface], holding [address]; one
/// other VPN's TUN, [decoy], which owns the route to the Magic DNS server and
/// already carries the leaked zone; and, when a test needs the configured TUN
/// name to differ from the link owning the address, [named].
///
/// The decoy is answered on purpose: an interface resolved through a route to
/// the Magic DNS server is the bug these fakes lock away from.
CommandResult? Function(String, List<String>) linuxHost({
  String interface = 'et_12_xoih',
  String address = '10.126.126.2/24',
  String? named,
  String decoy = 'FlClash',
  bool Function()? configured,
  bool resolvectl = true,
}) {
  final links = <String, String>{
    interface: address,
    decoy: '198.18.0.1/30',
    ?named: '',
  };
  return (executable, arguments) {
    if (executable == 'ip') return _ip(arguments, links, decoy);
    if (executable != 'resolvectl') return null;
    if (!resolvectl) {
      throw ProcessException(executable, arguments, 'not found', 127);
    }
    final name = arguments.length > 1 ? arguments[1] : '';
    // The other VPN's link still holds the zone the service applied to it.
    final shows =
        name == decoy || (name == interface && (configured?.call() ?? false));
    if (arguments.first == 'dns') {
      return ok(shows ? 'Link 5 ($name): 100.100.100.101' : 'Link 5 ($name):');
    }
    if (arguments.first == 'domain') {
      return ok(shows ? 'Link 5 ($name): ~et.net' : 'Link 5 ($name):');
    }
    return null;
  };
}

/// The Magic DNS system of a Linux host driven by [command].
MagicDnsSystem linuxSystem(FakeSystemCommand command) =>
    MagicDnsSystem(platform: MagicDnsPlatform.linux, command: command);

/// The Magic DNS system of a Windows host driven by [command].
MagicDnsSystem windowsSystem(FakeSystemCommand command) =>
    MagicDnsSystem(platform: MagicDnsPlatform.windows, command: command);

/// The Magic DNS system of the Android root service driven by [command].
MagicDnsSystem androidSystem(FakeSystemCommand command) =>
    MagicDnsSystem(platform: MagicDnsPlatform.android, command: command);

/// An Android host where the EasyTier TUN is [interface] holding [address],
/// whose `iptables`, when it exists at all, can load the matches
/// when [matches] says so, where the zone's rule is installed when
/// [configured] says so and the jump from OUTPUT is there when [jump] does,
/// and whose resolver file holds [resolvConf].
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
