import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/controllers/home/home_controller.dart';
import 'package:yukari_core/models/models.dart';

void main() {
  test('lists IPv4 and IPv6 virtual addresses for one running network', () {
    final network = Network()..networkName = 'dual-stack';
    final myself = Peer(
      id: 'local',
      identityType: IdentityType.admin,
      hostname: 'device',
      latency: null,
      rxBytes: 0,
      txBytes: 0,
      rxPackets: 0,
      txPackets: 0,
      secureAuthLevel: SecureAuthLevel.networkSecretConfirmed,
      protocols: const [],
      natType: NatType.unknown,
      connectionType: PeerConnectionType.local,
      virtualIpv4: '10.1.0.2',
      virtualIpv6: 'fd00::2',
    );
    final instance = Instance(
      network: network,
      status: InstanceStatus.running,
      events: const [],
      myself: myself,
      peers: const [],
    );

    expect(homeAddressesOf([instance]).map((entry) => entry.address), [
      '10.1.0.2',
      'fd00::2',
    ]);
  });
}
