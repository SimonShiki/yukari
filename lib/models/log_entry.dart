import 'dart:convert';

enum LogCategory { peer, connection, listener, system }

enum LogSeverity { info, success, warning, error }

/// One EasyTier `GlobalCtxEvent`, recorded as `{"time": …, "event": …}`.
///
/// Events use serde's externally tagged form: unit variants are bare strings,
/// others are a single-key object whose value is the variant's payload.
final class LogEntry {
  LogEntry._(this.raw, this.time, this.kind, this.payload);

  /// Parses a journal line. Malformed lines are kept with kind `Unknown`.
  factory LogEntry.parse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      final time = DateTime.tryParse(json['time'] as String? ?? '');
      return switch (json['event']) {
        String kind => LogEntry._(raw, time, kind, null),
        Map<String, Object?> event when event.length == 1 => LogEntry._(
          raw,
          time,
          event.keys.single,
          event.values.single,
        ),
        _ => LogEntry._(raw, time, 'Unknown', json['event']),
      };
    } catch (_) {
      return LogEntry._(raw, null, 'Unknown', raw);
    }
  }

  /// The journal line, which also identifies the entry.
  final String raw;
  final DateTime? time;

  /// The `GlobalCtxEvent` variant name, such as `PeerAdded`.
  final String kind;

  /// The variant payload: a scalar, a list for tuple variants, or a map.
  final Object? payload;

  late final LogCategory category = switch (kind) {
    'PeerAdded' ||
    'PeerRemoved' ||
    'PeerConnAdded' ||
    'PeerConnRemoved' => LogCategory.peer,
    'Connecting' ||
    'ConnectError' ||
    'ConnectionAccepted' ||
    'ConnectionError' => LogCategory.connection,
    'ListenerAdded' ||
    'ListenerAddFailed' ||
    'ListenerAcceptFailed' ||
    'ListenerPortMappingEstablished' => LogCategory.listener,
    _ => LogCategory.system,
  };

  late final LogSeverity severity = switch (kind) {
    'TunDeviceError' ||
    'ListenerAddFailed' ||
    'ListenerAcceptFailed' ||
    'ConnectionError' ||
    'ConnectError' ||
    'DhcpIpv4Conflicted' ||
    'Unknown' => LogSeverity.error,
    'UdpBroadcastRelayStartResult' when _field('error') != null =>
      LogSeverity.error,
    'PeerRemoved' ||
    'PeerConnRemoved' ||
    'VpnPortalClientDisconnected' => LogSeverity.warning,
    'TunDeviceReady' ||
    'PeerAdded' ||
    'PeerConnAdded' ||
    'ListenerAdded' ||
    'ListenerPortMappingEstablished' ||
    'ConnectionAccepted' ||
    'VpnPortalStarted' ||
    'VpnPortalClientConnected' => LogSeverity.success,
    _ => LogSeverity.info,
  };

  /// A one-line, human readable description of the event.
  late final String summary = switch (kind) {
    'TunDeviceReady' => 'TUN device ready: ${_arg(0)}',
    'TunDeviceError' => 'TUN device error: ${_arg(0)}',
    'PeerAdded' => 'Peer ${_arg(0)} joined',
    'PeerRemoved' => 'Peer ${_arg(0)} left',
    'PeerConnAdded' => 'Connected to peer ${_conn()}',
    'PeerConnRemoved' => 'Disconnected from peer ${_conn()}',
    'ListenerAdded' => 'Listening on ${_arg(0)}',
    'ListenerAddFailed' => 'Cannot listen on ${_arg(0)}: ${_arg(1)}',
    'ListenerAcceptFailed' => 'Listener ${_arg(0)} failed: ${_arg(1)}',
    'ListenerPortMappingEstablished' =>
      'Mapped ${_field('local_listener')} to ${_field('mapped_listener')} '
          'via ${_field('backend')}',
    'Connecting' => 'Connecting to ${_arg(0)}',
    'ConnectError' => 'Cannot connect to ${_arg(0)} (${_arg(1)}): ${_arg(2)}',
    'ConnectionAccepted' => 'Accepted ${_arg(1)} on ${_arg(0)}',
    'ConnectionError' =>
      'Connection ${_arg(1)} on ${_arg(0)} failed: ${_arg(2)}',
    'VpnPortalStarted' => 'VPN portal started: ${_arg(0)}',
    'VpnPortalClientConnected' => 'VPN client ${_arg(1)} connected',
    'VpnPortalClientDisconnected' => 'VPN client ${_arg(1)} disconnected',
    'DhcpIpv4Changed' => 'DHCP IPv4 changed from ${_arg(0)} to ${_arg(1)}',
    'DhcpIpv4Conflicted' => 'DHCP IPv4 ${_arg(0)} conflicted',
    'PublicIpv6Changed' => 'Public IPv6 changed from ${_arg(0)} to ${_arg(1)}',
    'PublicIpv6RoutesUpdated' => 'IPv6 routes updated: +${_arg(0)} −${_arg(1)}',
    'ProxyCidrsUpdated' => 'Proxy CIDRs updated: +${_arg(0)} −${_arg(1)}',
    'PortForwardAdded' => 'Port forward added',
    'ConfigPatched' => 'Configuration patched',
    'CredentialChanged' => 'Credential changed',
    'UdpBroadcastRelayStartResult' =>
      _field('error') == null
          ? 'UDP broadcast relay started via ${_field('capture_backend')}'
          : 'UDP broadcast relay failed: ${_field('error')}',
    'Unknown' => 'Unrecognized log entry',
    _ => kind,
  };

  /// The payload flattened to `path: value` pairs, such as
  /// `tunnel.remote_addr.url: tcp://…`.
  late final List<(String, String)> details = [
    ('event', kind),
    if (time != null) ('time', time!.toLocal().toString()),
    if (payload != null) ..._flatten('', payload),
  ];

  String _arg(int index) => _text(switch (payload) {
    List<Object?> list => index < list.length ? list[index] : null,
    final value => index == 0 ? value : null,
  });

  String? _field(String key) => switch (_path([key])) {
    null => null,
    final value => _text(value),
  };

  String _conn() =>
      '${_text(_path(['peer_id']))} via '
      '${_text(_path(['tunnel', 'tunnel_type']))} '
      '${_text(_path(['tunnel', 'remote_addr']))}';

  Object? _path(List<String> keys) {
    Object? value = payload;
    for (final key in keys) {
      value = value is Map ? value[key] : null;
    }
    return value;
  }

  /// Renders protobuf `Url` wrappers, CIDR lists and absent options.
  static String _text(Object? value) => switch (value) {
    null => 'none',
    {'url': final Object url} => '$url',
    List<Object?> list when list.isEmpty => 'none',
    List<Object?> list => list.map(_text).join(', '),
    _ => '$value',
  };

  static Iterable<(String, String)> _flatten(String path, Object? value) sync* {
    switch (value) {
      case Map<String, Object?> map when map.length == 1 && map['url'] != null:
        yield (path, '${map['url']}');
      case Map<String, Object?> map when map.isNotEmpty:
        for (final MapEntry(:key, :value) in map.entries) {
          yield* _flatten(path.isEmpty ? key : '$path.$key', value);
        }
      // Tuple variants are lists too, so expand those at the root.
      case List<Object?> list
          when path.isEmpty || list.any((item) => item is Map || item is List):
        for (var index = 0; index < list.length; index++) {
          yield* _flatten('$path[$index]', list[index]);
        }
      default:
        yield (path.isEmpty ? 'value' : path, _text(value));
    }
  }
}
