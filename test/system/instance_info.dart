/// EasyTier information of one running instance, shared across tests.
Map<String, Object?> instanceInfo({
  String hostname = 'alpha',
  String natType = 'Unknown',
  String virtualIpv4 = '10.144.0.2',
  List<Map<String, Object?>> peers = const [],
}) => {
  'running': true,
  'my_node_info': {
    'peer_id': 1,
    'hostname': hostname,
    'virtual_ipv4': {
      'address': {'addr': _ipv4(virtualIpv4)},
    },
    'stun_info': {'udp_nat_type': natType},
  },
  'peer_route_pairs': peers,
};

/// One connected peer with [rx] and [tx] byte totals.
Map<String, Object?> instancePeer({int rx = 1000, int tx = 2000}) => {
  'route': {
    'peer_id': '2',
    'hostname': 'peer-one',
    'ipv4_addr': {
      'address': {'addr': _ipv4('10.144.0.9')},
    },
  },
  'peer': {
    'conns': [
      {
        'stats': {'rx_bytes': '$rx', 'tx_bytes': '$tx'},
      },
    ],
  },
};

int _ipv4(String address) =>
    address.split('.').fold(0, (value, part) => (value << 8) | int.parse(part));
