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
  List<String> proxyCidrs = const [],
}) => Network()
  ..networkName = name
  ..ipv4 = ipv4
  ..proxyNetworks = [
    for (final cidr in proxyCidrs) ProxyNetwork(cidr: cidr),
  ]
  ..flags = (NetworkFlags()
    ..acceptDns = acceptDns
    ..noTun = noTun);

Instance _instance(String name, {bool noTun = false}) => Instance(
  network: _network(name: name, noTun: noTun),
  status: InstanceStatus.running,
  events: const [],
  myself: null,
  peers: const [],
);

/// A VPN whose calls are recorded; [record] is what an [AndroidBackend] drives.
class _RecordingVpn {
  _RecordingVpn({this.fd = 7});

  final int fd;
  Object? startError;
  Object? stopError;
  final started = <String>[];
  var stops = 0;
  var permissions = 0;

  AndroidVpn get record => (
    start:
        ({
          required String networkName,
          required String ipv4,
          required int mtu,
          required List<String> routes,
          String? dns,
        }) async {
          started.add(networkName);
          if (startError case final error?) throw error;
          return fd;
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
  String? tunName;
  int? tunFd;

  @override
  Future<void> runInstance(String config) async => ran.add(config);

  @override
  Future<void> deleteInstances(List<String> names) async =>
      deleted.addAll(names);

  @override
  Future<void> setTunFd(String instanceName, int fd) async {
    tunName = instanceName;
    tunFd = fd;
  }
}

void main() {
  group('androidVpnRequest', () {
    test('a Magic DNS network gets the server and a route to it', () {
      final request = androidVpnRequest(_network());

      expect(request.dns, magicDnsServer);
      expect(request.routes, ['10.144.144.0/24', '100.100.100.101/32']);
    });

    test('a network without Magic DNS gets neither', () {
      final request = androidVpnRequest(_network(acceptDns: false));

      expect(request.dns, isNull);
      expect(request.routes, ['10.144.144.0/24']);
    });

    test('a network without a TUN gets neither', () {
      final request = androidVpnRequest(_network(noTun: true));

      expect(request.dns, isNull);
      expect(request.routes, ['10.144.144.0/24']);
    });

    test('the route is the address network, while the address is the host', () {
      final request = androidVpnRequest(
        _network(ipv4: '10.126.126.2/24', proxyCidrs: ['192.168.1.0/24']),
      );

      expect(request.ipv4, '10.126.126.2/24');
      expect(request.mtu, 1420);
      expect(request.routes, [
        '10.126.126.0/24',
        '192.168.1.0/24',
        '100.100.100.101/32',
      ]);
    });

    test('an address without a prefix becomes its /24 network', () {
      final request = androidVpnRequest(_network(ipv4: '10.126.126.1'));

      expect(request.routes, ['10.126.126.0/24', '100.100.100.101/32']);
    });
  });

  group('ipv4NetworkCidr', () {
    test('clears the host bits the prefix leaves out', () {
      expect(ipv4NetworkCidr('10.126.126.2/24'), '10.126.126.0/24');
      expect(ipv4NetworkCidr('192.168.1.130/25'), '192.168.1.128/25');
      expect(ipv4NetworkCidr('10.1.2.3/8'), '10.0.0.0/8');
      expect(ipv4NetworkCidr('10.1.2.3/0'), '0.0.0.0/0');
    });

    test('keeps a host route and takes a bare address as its /24', () {
      expect(ipv4NetworkCidr('100.100.100.101/32'), '100.100.100.101/32');
      expect(ipv4NetworkCidr('10.126.126.2'), '10.126.126.0/24');
      expect(ipv4NetworkCidr('192.168.5.9'), '192.168.5.0/24');
    });

    test('hands back input the platform never accepted', () {
      expect(ipv4NetworkCidr('fd00::1/64'), 'fd00::1/64');
      expect(ipv4NetworkCidr('not-an-ip/24'), 'not-an-ip/24');
      expect(ipv4NetworkCidr('10.0.0.1/33'), '10.0.0.1/33');
      expect(ipv4NetworkCidr('10.1.2.3/8/9'), '10.1.2.3/8/9');
    });
  });

  group('AndroidBackend', () {
    test('one TUN network may run, and any number without one', () {
      final backend = AndroidBackend();
      addTearDown(backend.dispose);
      final tun = _instance('alpha');
      final noTun = _instance('beta', noTun: true);

      expect(backend.maxTunInstances, 1);
      expect(backend.canStart(_network(name: 'gamma'), [tun]), isFalse);
      expect(backend.canStart(_network(name: 'gamma'), [noTun]), isTrue);
      expect(
        backend.canStart(_network(name: 'gamma', noTun: true), [tun]),
        isTrue,
      );
      expect(backend.canStart(_network(name: 'gamma'), []), isTrue);
    });

    test('a TUN network takes the VPN and hands over its fd', () async {
      final vpn = _RecordingVpn(fd: 9);
      final backend = _TestAndroidBackend(vpn.record);
      addTearDown(backend.dispose);

      await backend.start('n1', _network(ipv4: '10.126.126.2/24'));

      expect(vpn.started, ['alpha']);
      expect(backend.tunName, 'alpha');
      expect(backend.tunFd, 9);
    });

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

    test('a failed second start leaves the owner\'s VPN up', () async {
      final vpn = _RecordingVpn();
      final backend = _TestAndroidBackend(vpn.record);
      addTearDown(backend.dispose);
      await backend.start('n1', _network());
      vpn.startError = StateError('Bad address');

      await expectLater(
        backend.start('n2', _network(name: 'beta')),
        throwsStateError,
      );

      expect(vpn.stops, 0, reason: 'alpha still owns the VPN service');
      await backend.stop(['alpha']);
      expect(vpn.stops, 1, reason: 'its owner can still stop it');
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
