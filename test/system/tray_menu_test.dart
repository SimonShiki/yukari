import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/controllers/home_controller.dart' show TrafficSample;
import 'package:yukari/system/tray_menu.dart';

void main() {
  const TrafficSample sample = (
    received: 10,
    sent: 20,
    receiveRate: 1536,
    sendRate: 300,
    at: null,
  );

  test('a stopped network is labeled with its name alone', () {
    expect(
      trayNetworkLabel(
        'alpha',
        peers: '2 peers',
        address: '10.144.144.10',
        traffic: null,
      ),
      'alpha',
    );
  });

  test('a running network adds peers, its own address and traffic', () {
    expect(
      trayNetworkLabel(
        'alpha',
        peers: '2 peers',
        address: '10.144.144.10',
        traffic: sample,
      ),
      'alpha · 2 peers · 10.144.144.10 · ↓ 1.5 KB/s  ↑ 300 B/s',
    );
  });

  test('a missing address leaves that part out', () {
    expect(
      trayNetworkLabel(
        'alpha',
        peers: '1 peer',
        address: null,
        traffic: sample,
      ),
      'alpha · 1 peer · ↓ 1.5 KB/s  ↑ 300 B/s',
    );
  });
}
