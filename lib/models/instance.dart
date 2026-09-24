import 'network.dart';
import 'peer.dart';

enum InstanceStatus { stopped, starting, running, stopping, failed, unknown }

final class Instance {
  Instance({
    required this.network,
    required this.status,
    required this.events,
    required this.myself,
    required this.peers,
  });

  /// The network that this instance spawned from.
  final Network network;
  final InstanceStatus status;
  final List<String> events;
  final Peer? myself;
  final List<Peer> peers;

  factory Instance.fromJsonAndNetwork(
    Map<String, Object?> json,
    Network network,
  ) {
    final myNodeInfo = json['my_node_info'] as Map<String, Object?>?;
    final myPeer = myNodeInfo != null
        ? Peer(
            id: '${myNodeInfo['peer_id']}',
            identityType: IdentityType.admin,
            hostname: myNodeInfo['hostname'] as String,
            latency: 0,
            rxBytes: 0,
            txBytes: 0,
            rxPackets: 0,
            txPackets: 0,
            secureAuthLevel: SecureAuthLevel.networkSecretConfirmed,
            protocols: const [],
            natType: NatType.unknown,
            connectionType: PeerConnectionType.local,
          )
        : null;
    final pairs = (json['peer_route_pairs'] as List<Object?>?)
        ?.whereType<Map<String, Object?>>() ?? [];
    final running = json['running'] as bool? ?? false;
    final error = json['error_msg'] as String?;

    return Instance(
      network: network,
      status: error != null && error.isNotEmpty
          ? InstanceStatus.failed
          : running
          ? InstanceStatus.running
          : InstanceStatus.stopped,
      events: (json['events'] as List<Object?>?)?.cast<String>() ?? [],
      myself: myPeer,
      peers: pairs
          .map((pair) {
            try {
              return Peer.fromJson(pair);
            } catch (_) {
              return null;
            }
          })
          .whereType<Peer>()
          .toList(growable: false),
    );
  }
}
