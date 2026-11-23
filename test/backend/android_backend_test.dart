import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/backend/android_backend.dart';
import 'package:yukari/backend/android_vpn.dart';
import 'package:yukari_core/models/models.dart';
import 'package:yukari_core/system/magic_dns.dart';

Network _network({
  String name = 'alpha',
  bool acceptDns = true,
  bool noTun = false,
  String? ipv4,
  String? ipv6,
  String? dhcpIpv4Cidr,
  int mtu = 1380,
  List<String> proxyCidrs = const [],
}) => Network()
  ..networkName = name
  ..ipv4 = ipv4
  ..ipv6 = ipv6
  ..dhcpIpv4Cidr = dhcpIpv4Cidr
  ..proxyNetworks = [for (final cidr in proxyCidrs) ProxyNetwork(cidr: cidr)]
  ..flags = (NetworkFlags()
    ..acceptDns = acceptDns
    ..noTun = noTun
    ..mtu = mtu);

typedef _VpnStartCall = ({
  String networkName,
  List<String> addresses,
  int mtu,
  List<String> routes,
  String? dns,
});

/// A VPN whose calls are recorded; [record] is what an [AndroidBackend] drives.
class _RecordingVpn {
  _RecordingVpn({this.nextFd = 7});

  int nextFd;
  Object? startError;
  final failingNames = <String>{};
  Object? stopError;
  final started = <_VpnStartCall>[];
  var stops = 0;
  var permissions = 0;

  AndroidVpn get record => (
    start:
        ({
          required String networkName,
          required List<String> addresses,
          required int mtu,
          required List<String> routes,
          String? dns,
        }) async {
          started.add((
            networkName: networkName,
            addresses: addresses,
            mtu: mtu,
            routes: routes,
            dns: dns,
          ));
          if (startError case final error?) throw error;
          if (failingNames.contains(networkName)) {
            throw StateError('configured VPN failure');
          }
          return nextFd++;
        },
    stop: () async {
      stops++;
      if (stopError case final error?) throw error;
    },
    requestPermission: () async {
      permissions++;
      return false;
    },
  );
}

/// An [AndroidBackend] whose EasyTier side is recorded instead of run.
class _TestAndroidBackend extends AndroidBackend {
  _TestAndroidBackend(AndroidVpn vpn) : super(vpn: vpn);

  final ran = <String>[];
  final deleted = <String>[];
  final tunCalls = <(String, int)>[];
  Map<String, Object?> collected = const {};
  int? failNextAttachFd;

  String? get tunName => tunCalls.isEmpty ? null : tunCalls.last.$1;
  int? get tunFd => tunCalls.isEmpty ? null : tunCalls.last.$2;

  @override
  Future<void> runInstance(String config) async => ran.add(config);

  @override
  Future<void> deleteInstances(List<String> names) async =>
      deleted.addAll(names);

  @override
  Future<Map<String, String>> readNetworkInfos() async => {
    for (final entry in collected.entries) entry.key: jsonEncode(entry.value),
  };

  @override
  Future<void> setTunFd(String instanceName, int fd) async {
    tunCalls.add((instanceName, fd));
    if (fd != 0 && fd == failNextAttachFd) {
      failNextAttachFd = null;
      throw StateError('TUN attach failed');
    }
  }
}

void main() {
  group('androidVpnRequest', () {
    test('a Magic DNS network gets the server and a route to it', () {
      final request = androidVpnRequest(_network());

      expect(request.dns, magicDnsServer);
      expect(request.addresses, ['10.126.126.1/24']);
      expect(request.routes, ['10.126.126.0/24', '100.100.100.101/32']);
    });

    test('a network without Magic DNS gets neither', () {
      final request = androidVpnRequest(_network(acceptDns: false));

      expect(request.dns, isNull);
      expect(request.routes, ['10.126.126.0/24']);
    });

    test('a network without a TUN gets neither', () {
      final request = androidVpnRequest(_network(noTun: true));

      expect(request.dns, isNull);
      expect(request.routes, ['10.126.126.0/24']);
    });

    test('the route is the address network, while the address is the host', () {
      final request = androidVpnRequest(
        _network(
          ipv4: '10.126.126.2/24',
          mtu: 1420,
          proxyCidrs: ['192.168.1.0/24'],
        ),
      );

      expect(request.addresses, ['10.126.126.2/24']);
      expect(request.mtu, 1420);
      expect(request.routes, [
        '10.126.126.0/24',
        '100.100.100.101/32',
        '192.168.1.0/24',
      ]);
    });

    test('an address without a prefix becomes its /24 network', () {
      final request = androidVpnRequest(_network(ipv4: '10.126.126.1'));

      expect(request.addresses, ['10.126.126.1/24']);
      expect(request.routes, ['10.126.126.0/24', '100.100.100.101/32']);
    });

    test('uses custom dhcpIpv4Cidr for initial bootstrap route', () {
      final request = androidVpnRequest(
        _network(dhcpIpv4Cidr: '192.168.100.0/24'),
      );

      expect(request.addresses, ['192.168.100.1/24']);
      expect(request.routes, ['100.100.100.101/32', '192.168.100.0/24']);
    });

    test('bootstraps DHCPv6 default and custom subnets alongside DHCPv4', () {
      final v6Only = androidVpnRequest(
        _network()
          ..dhcp = false
          ..dhcpv6 = true,
      );
      expect(v6Only.addresses, ['fd6b:8c2d:91e4::1/64']);
      expect(v6Only.routes, ['100.100.100.101/32', 'fd6b:8c2d:91e4::/64']);

      final dualStack = androidVpnRequest(
        _network(dhcpIpv4Cidr: '192.168.100.0/24')
          ..dhcpv6 = true
          ..dhcpIpv6Cidr = 'fd42:1234::/64',
      );
      expect(dualStack.addresses, ['192.168.100.1/24', 'fd42:1234::1/64']);
      expect(dualStack.routes, [
        '100.100.100.101/32',
        '192.168.100.0/24',
        'fd42:1234::/64',
      ]);
    });

    test('dual-stack DHCP keeps its IPv4 bootstrap with static IPv6', () {
      final request = androidVpnRequest(
        _network(ipv6: 'fd00::1/64')..dhcp = true,
      );

      expect(request.addresses, ['10.126.126.1/24', 'fd00::1/64']);
      expect(request.routes, [
        '10.126.126.0/24',
        '100.100.100.101/32',
        'fd00::/64',
      ]);
    });

    test(
      'aggregates multiple members including IPv6 and deduplicates Magic DNS',
      () {
        final config = buildAndroidVpnConfig([
          AndroidVpnMember(
            network: _network(name: 'alpha', ipv4: '10.1.0.2/24', mtu: 1420),
          ),
          AndroidVpnMember(
            network: _network(
              name: 'beta',
              ipv4: '10.2.0.2/24',
              ipv6: 'fd00:2::2/64',
              mtu: 1300,
            ),
          ),
        ]);

        expect(config.networkNames, ['alpha', 'beta']);
        expect(config.addresses, [
          '10.1.0.2/24',
          '10.2.0.2/24',
          'fd00:2::2/64',
        ]);
        expect(config.routes, [
          '10.1.0.0/24',
          '10.2.0.0/24',
          '100.100.100.101/32',
          'fd00:2::/64',
        ]);
        expect(config.mtu, 1300);
        expect(config.dns, magicDnsServer);
      },
    );
  });

  group('CIDR helpers', () {
    test('ipNetworkCidr normalizes both IPv4 and IPv6', () {
      expect(ipNetworkCidr('fd00:1::5/64'), 'fd00:1::/64');
      expect(ipNetworkCidr('fd00:1::5'), 'fd00:1::/64');
      expect(ipNetworkCidr('10.126.126.2/24'), '10.126.126.0/24');
    });

    test(
      'cidrsOverlap and findVpnRouteConflict detect overlapping subnets',
      () {
        expect(cidrsOverlap('10.1.0.0/16', '10.1.2.0/24'), isTrue);
        expect(cidrsOverlap('10.1.0.0/24', '10.2.0.0/24'), isFalse);
        expect(cidrsOverlap('fd00:1::/64', 'fd00:1::1/128'), isTrue);
        expect(cidrsOverlap('10.1.0.0/24', 'fd00:1::/64'), isFalse);

        final existing = [
          AndroidVpnMember(
            network: _network(name: 'alpha', ipv4: '10.1.0.1/24'),
          ),
        ];
        // Shared Magic DNS /32 is exempt.
        expect(
          findVpnRouteConflict(
            existing,
            AndroidVpnMember(
              network: _network(name: 'beta', ipv4: '10.2.0.1/24'),
            ),
          ),
          isNull,
        );
        expect(
          findVpnRouteConflict(
            existing,
            AndroidVpnMember(
              network: _network(
                name: 'beta',
                ipv4: '10.2.0.1/24',
                proxyCidrs: ['10.1.0.0/24'],
              ),
            ),
          ),
          contains('alpha'),
        );
      },
    );

    test(
      'shared Magic DNS route conflicts with exact and broad proxy routes',
      () {
        final dnsOwner = AndroidVpnMember(
          network: _network(name: 'dns', ipv4: '10.1.0.1/24'),
        );
        for (final proxyCidr in ['100.100.100.101/32', '100.100.100.0/24']) {
          expect(
            findVpnRouteConflict(
              [dnsOwner],
              AndroidVpnMember(
                network: _network(
                  name: 'proxy',
                  acceptDns: false,
                  ipv4: '10.2.0.1/24',
                  proxyCidrs: [proxyCidr],
                ),
              ),
            ),
            isNotNull,
          );
        }
        expect(
          findVpnRouteConflict(
            const <AndroidVpnMember>[],
            AndroidVpnMember(
              network: _network(
                name: 'dns-and-proxy',
                proxyCidrs: ['100.100.100.0/24'],
              ),
            ),
          ),
          isNotNull,
        );
      },
    );

    test('parseAssignedAddresses reads protobuf JSON shapes', () {
      final parsed = parseAssignedAddresses(
        jsonEncode({
          'my_node_info': {
            'virtual_ipv4': {
              'address': {'addr': 176061954},
              'network_length': 24,
            },
            'virtual_ipv6': {
              'address': {
                'part1': 0xfd000000,
                'part2': 0,
                'part3': 0,
                'part4': 2,
              },
              'network_length': 64,
            },
          },
        }),
      );
      expect(parsed.ipv4, '10.126.126.2/24');
      expect(parsed.ipv6, 'fd00::2/64');
    });
  });

  group('AndroidBackend', () {
    test('a TUN network takes the VPN and hands over its fd', () async {
      final vpn = _RecordingVpn(nextFd: 9);
      final backend = _TestAndroidBackend(vpn.record);
      addTearDown(backend.dispose);

      await backend.start('n1', _network(ipv4: '10.126.126.2/24'));

      expect(vpn.started.single.networkName, 'alpha');
      expect(vpn.started.single.addresses, ['10.126.126.2/24']);
      expect(backend.tunName, 'alpha');
      expect(backend.tunFd, 9);
    });

    test('two disjoint TUN networks share one rebuilt VPN', () async {
      final vpn = _RecordingVpn(nextFd: 9);
      final backend = _TestAndroidBackend(vpn.record);
      addTearDown(backend.dispose);

      await backend.start('n1', _network(name: 'alpha', ipv4: '10.1.0.1/24'));
      await backend.start('n2', _network(name: 'beta', ipv4: '10.2.0.1/24'));

      expect(vpn.started, hasLength(2));
      expect(vpn.started.last.addresses, ['10.1.0.1/24', '10.2.0.1/24']);
      expect(vpn.started.last.routes, [
        '10.1.0.0/24',
        '10.2.0.0/24',
        '100.100.100.101/32',
      ]);
      // Existing member was detached (0) before rebuilding, then both got fd 10.
      expect(backend.tunCalls, [
        ('alpha', 9),
        ('alpha', 0),
        ('alpha', 10),
        ('beta', 10),
      ]);
      expect(vpn.stops, 0);
    });

    test(
      'stopping one of two TUN networks rebuilds for the remaining one',
      () async {
        final vpn = _RecordingVpn(nextFd: 9);
        final backend = _TestAndroidBackend(vpn.record);
        addTearDown(backend.dispose);

        await backend.start('n1', _network(name: 'alpha', ipv4: '10.1.0.1/24'));
        await backend.start('n2', _network(name: 'beta', ipv4: '10.2.0.1/24'));
        backend.tunCalls.clear();

        await backend.stop(['alpha']);

        expect(vpn.stops, 0, reason: 'beta still uses the shared VPN');
        expect(vpn.started.last.networkName, 'beta');
        expect(vpn.started.last.addresses, ['10.2.0.1/24']);
        expect(backend.tunCalls, [('beta', 0), ('beta', 11)]);

        await backend.stop(['beta']);
        expect(vpn.stops, 1, reason: 'last TUN network tears down the VPN');
      },
    );

    test(
      'rejects an overlapping second network without dropping the first',
      () async {
        final vpn = _RecordingVpn(nextFd: 9);
        final backend = _TestAndroidBackend(vpn.record);
        addTearDown(backend.dispose);

        await backend.start('n1', _network(name: 'alpha'));

        await expectLater(
          backend.start('n2', _network(name: 'beta')),
          throwsStateError,
        );
        expect(vpn.started, hasLength(1));
        expect(vpn.stops, 0);
        expect(backend.ran, hasLength(1));
      },
    );

    test('a no-TUN network never touches the VPN', () async {
      final vpn = _RecordingVpn();
      final backend = _TestAndroidBackend(vpn.record);
      addTearDown(backend.dispose);

      await backend.start('n1', _network(noTun: true));

      expect(vpn.started, isEmpty);
      expect(backend.ran, hasLength(1));
    });

    test('stopping a no-TUN network leaves the running VPN up', () async {
      final vpn = _RecordingVpn();
      final backend = _TestAndroidBackend(vpn.record);
      addTearDown(backend.dispose);
      await backend.start('n1', _network());
      await backend.start('n2', _network(name: 'beta', noTun: true));

      await backend.stop(['beta']);
      expect(vpn.stops, 0, reason: 'the TUN network still owns the VPN');

      await backend.stop(['alpha']);
      expect(vpn.stops, 1, reason: 'its owner stopped the VPN');
    });

    test('a failed start stops the instance and the VPN service', () async {
      final vpn = _RecordingVpn()..startError = StateError('Bad address');
      final backend = _TestAndroidBackend(vpn.record);
      addTearDown(backend.dispose);

      await expectLater(backend.start('n1', _network()), throwsStateError);

      expect(backend.deleted, ['alpha']);
      expect(vpn.stops, 1, reason: 'a failed start leaves no VPN behind');
    });

    test(
      'a failed second start restores the surviving network\'s fd',
      () async {
        final vpn = _RecordingVpn(nextFd: 9);
        final backend = _TestAndroidBackend(vpn.record);
        addTearDown(backend.dispose);
        await backend.start('n1', _network(name: 'alpha', ipv4: '10.1.0.1/24'));
        vpn.startError = StateError('Bad address');
        backend.tunCalls.clear();

        await expectLater(
          backend.start('n2', _network(name: 'beta', ipv4: '10.2.0.1/24')),
          throwsStateError,
        );

        expect(vpn.stops, 0, reason: 'alpha still owns the VPN service');
        expect(backend.deleted, ['beta']);
        expect(backend.tunCalls, [('alpha', 0), ('alpha', 9)]);

        await backend.stop(['alpha']);
        expect(vpn.stops, 1, reason: 'its owner can still stop it');
      },
    );

    test(
      'a failed attach after replacement restores the previous VPN config',
      () async {
        final vpn = _RecordingVpn(nextFd: 9);
        final backend = _TestAndroidBackend(vpn.record);
        addTearDown(backend.dispose);
        await backend.start('n1', _network(name: 'alpha', ipv4: '10.1.0.1/24'));
        backend.failNextAttachFd = 10;

        await expectLater(
          backend.start('n2', _network(name: 'beta', ipv4: '10.2.0.1/24')),
          throwsStateError,
        );

        expect(backend.deleted, ['beta']);
        expect(vpn.started, hasLength(3));
        expect(vpn.started.last.networkName, 'alpha');
        expect(vpn.stops, 0);
        expect(backend.tunCalls.last, ('alpha', 11));
      },
    );

    test(
      'a failed rollback establishment keeps the current FD for retry',
      () async {
        final vpn = _RecordingVpn(nextFd: 9);
        final backend = _TestAndroidBackend(vpn.record);
        addTearDown(backend.dispose);
        await backend.start('n1', _network(name: 'alpha', ipv4: '10.1.0.1/24'));
        vpn.failingNames.add('alpha');
        backend.failNextAttachFd = 10;

        await expectLater(
          backend.start('n2', _network(name: 'beta', ipv4: '10.2.0.1/24')),
          throwsStateError,
        );

        expect(vpn.stops, 0);
        expect(backend.tunCalls.last, ('alpha', 10));
        vpn.failingNames.clear();
        await backend.collectInfos();
        await pumpEventQueue();
        expect(vpn.started.last.networkName, 'alpha');
        expect(vpn.started.last.addresses, ['10.1.0.1/24']);
        expect(backend.tunCalls.last, ('alpha', 11));
      },
    );

    test(
      'collectInfos reconciles VPN when DHCP assigns a new address',
      () async {
        final vpn = _RecordingVpn(nextFd: 9);
        final backend = _TestAndroidBackend(vpn.record);
        addTearDown(backend.dispose);

        await backend.start('n1', _network(name: 'alpha'));
        expect(vpn.started.single.addresses, ['10.126.126.1/24']);

        backend.collected = {
          'alpha': {
            'running': true,
            'my_node_info': {
              'virtual_ipv4': {
                'address': {'addr': 176061957},
                'network_length': 24,
              },
            },
          },
        };
        await backend.collectInfos();
        await pumpEventQueue();

        expect(vpn.started, hasLength(2));
        expect(vpn.started.last.addresses, ['10.126.126.5/24']);
        expect(backend.tunCalls.last, ('alpha', 10));
      },
    );

    test('DHCP reconciliation retries after an attach failure', () async {
      final vpn = _RecordingVpn(nextFd: 9);
      final backend = _TestAndroidBackend(vpn.record);
      addTearDown(backend.dispose);
      await backend.start('n1', _network(name: 'alpha'));
      backend.failNextAttachFd = 10;
      backend.collected = {
        'alpha': {
          'running': true,
          'my_node_info': {
            'virtual_ipv4': {
              'address': {'addr': 176061957},
              'network_length': 24,
            },
          },
        },
      };

      await backend.collectInfos();
      await pumpEventQueue();
      expect(vpn.started, hasLength(3));
      expect(vpn.started.last.addresses, ['10.126.126.1/24']);

      await backend.collectInfos();
      await pumpEventQueue();
      expect(vpn.started, hasLength(4));
      expect(vpn.started.last.addresses, ['10.126.126.5/24']);
    });

    test('a throwing stop keeps the VPN ownership for a retry', () async {
      final vpn = _RecordingVpn();
      final backend = _TestAndroidBackend(vpn.record);
      addTearDown(backend.dispose);
      await backend.start('n1', _network());
      vpn.stopError = StateError('the channel is gone');

      await expectLater(backend.stop(['alpha']), throwsStateError);

      // The service may still be up, so the owner keeps it and tries again.
      vpn.stopError = null;
      await backend.stop(['alpha']);
      expect(vpn.stops, 2);
    });

    test(
      'a failed replacement during stop preserves the previous live FD',
      () async {
        final vpn = _RecordingVpn(nextFd: 7);
        final backend = _TestAndroidBackend(vpn.record);
        addTearDown(backend.dispose);
        await backend.start('n1', _network(name: 'alpha', ipv4: '10.1.0.1/24'));
        await backend.start('n2', _network(name: 'beta', ipv4: '10.2.0.1/24'));
        vpn.startError = StateError('replacement failed');

        await expectLater(backend.stop(['beta']), throwsStateError);

        expect(vpn.stops, 0);
        expect(backend.tunCalls.last, ('alpha', 8));
        vpn.startError = null;
        await backend.collectInfos();
        await pumpEventQueue();
        expect(vpn.started.last.networkName, 'alpha');

        await backend.stop(['alpha']);
        expect(vpn.stops, 1);
      },
    );

    test('dispose tears down a VPN a failed stop left behind', () async {
      final vpn = _RecordingVpn();
      final backend = _TestAndroidBackend(vpn.record);
      await backend.start('n1', _network());
      vpn.stopError = StateError('the channel is gone');
      await expectLater(backend.stop(['alpha']), throwsStateError);

      // The instance is gone and no later stop names it, so only disposing
      // the backend can still release the service.
      vpn.stopError = null;
      await backend.dispose();

      expect(vpn.stops, 2, reason: 'the abandoned VPN is stopped once more');
    });

    test('dispose stops no VPN when nothing owns one', () async {
      final vpn = _RecordingVpn();
      final backend = _TestAndroidBackend(vpn.record);
      await backend.start('n1', _network(noTun: true));

      await backend.dispose();

      expect(vpn.stops, 0);
    });

    test('disposing while a network runs releases the VPN once', () async {
      final vpn = _RecordingVpn();
      final backend = _TestAndroidBackend(vpn.record);
      await backend.start('n1', _network());

      await backend.dispose();
      expect(vpn.stops, 1);

      // The service is released, so the stop super.dispose issues for whatever
      // EasyTier still lists is not passed on to the VPN a second time.
      await backend.stop(['alpha']);
      expect(vpn.stops, 1);
    });

    test('handleVpnRevoked detaches active TUN members', () async {
      final vpn = _RecordingVpn(nextFd: 9);
      final backend = _TestAndroidBackend(vpn.record);
      addTearDown(backend.dispose);

      await backend.start('n1', _network(name: 'alpha', ipv4: '10.1.0.1/24'));
      backend.tunCalls.clear();

      await backend.handleVpnRevoked();

      expect(backend.tunCalls, [('alpha', 0)]);
      expect(vpn.stops, 0);
    });

    test('a no-TUN network asks for no VPN permission', () async {
      final vpn = _RecordingVpn();
      final backend = _TestAndroidBackend(vpn.record);
      addTearDown(backend.dispose);

      expect(await backend.tunAccess(_network(noTun: true)), TunAccess.granted);
      expect(vpn.permissions, 0);
    });
  });

  test('magicDnsRequested is the accept-DNS flag without a TUN exception', () {
    expect(magicDnsRequested(_network().flags), isTrue);
    expect(magicDnsRequested(_network(acceptDns: false).flags), isFalse);
    expect(magicDnsRequested(_network(noTun: true).flags), isFalse);
  });
}
