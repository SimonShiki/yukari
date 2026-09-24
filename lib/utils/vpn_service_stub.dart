class AndroidVpnService {
  static Future<bool> requestVpnPermission() async => false;

  static Future<int> startVpn({
    required String networkName,
    required String ipv4,
    required int mtu,
    required List<String> routes,
    String? dns,
  }) async {
    throw UnsupportedError('VPN service is only supported on Android');
  }

  static Future<void> stopVpn() async {}

  static Future<bool> isVpnActive() async => false;
}
