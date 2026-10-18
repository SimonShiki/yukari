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
    this.version,
  });

  /// The network that this instance spawned from.
  final Network network;
  final InstanceStatus status;
  final List<String> events;
  final Peer? myself;
  final List<Peer> peers;

  /// The EasyTier version running the instance, such as `2.7.0-1649ec00`.
  final String? version;

  /// The members of the network: the remote peers EasyTier reports plus this
  /// device, which `peer_route_pairs` leaves out.
  int get memberCount => peers.length + (myself == null ? 0 : 1);

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
            natType: Peer.natTypeOf(myNodeInfo['stun_info']),
            connectionType: PeerConnectionType.local,
            virtualIpv4: Peer.ipv4FromInet(myNodeInfo['virtual_ipv4']),
          )
        : null;
    final pairs =
        (json['peer_route_pairs'] as List<Object?>?)
            ?.whereType<Map<String, Object?>>() ??
        [];
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
      version: myNodeInfo?['version'] as String?,
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
