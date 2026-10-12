import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/models/models.dart';

void main() {
  // Captured from collect_network_infos of an instance connected to one peer.
  Map<String, Object?> collected() => jsonDecode(
    File('test/fixtures/collected_instance.json').readAsStringSync(),
  ) as Map<String, Object?>;

  test('reads peers as serialized by EasyTier', () {
    final instance = Instance.fromJsonAndNetwork(collected(), Network());

    expect(instance.status, InstanceStatus.running);
    expect(instance.events, hasLength(2));
    final peer = instance.peers.single;
    expect(peer.id, '1345173395');
    expect(peer.hostname, 'host-a');
    expect(peer.virtualIpv4, '10.144.0.1');
    expect(instance.myself!.virtualIpv4, '10.144.0.2');
    expect(peer.latency, 172);
    expect(peer.rxBytes, 1848);
    expect(peer.protocols, [NodeProtocol.tcp]);
    expect(peer.natType, NatType.symmetric);
    expect(peer.connectionType, PeerConnectionType.direct);
    // Omitted because it is the default value.
    expect(peer.secureAuthLevel, SecureAuthLevel.none);
  });

  test('reads enums by name or number', () {
    final json = collected();
    final pair =
        (json['peer_route_pairs'] as List<Object?>).single
            as Map<String, Object?>;
    final conn =
        ((pair['peer'] as Map<String, Object?>)['conns'] as List<Object?>)
                .single
            as Map<String, Object?>;
    conn['secure_auth_level'] = 'NetworkSecretConfirmed';
    conn['peer_identity_type'] = 2;

    final peer = Instance.fromJsonAndNetwork(json, Network()).peers.single;
    expect(peer.secureAuthLevel, SecureAuthLevel.networkSecretConfirmed);
    expect(peer.identityType, IdentityType.sharedNode);
  });
}
