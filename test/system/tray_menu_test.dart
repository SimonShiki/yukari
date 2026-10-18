import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/system/tray_menu.dart';

void main() {
  test('a stopped network is labeled with its name alone', () {
    expect(
      trayNetworkLabel(
        'alpha',
        peers: '2 peers',
        traffic: null,
      ),
      'alpha',
    );
  });
}
