/// EasyTier information of one running instance, shared by the tray and the
/// Android system UI tests.
Map<String, Object?> instanceInfo({
  List<Map<String, Object?>> peers = const [],
}) => {
  'running': true,
  'my_node_info': {
    'peer_id': 1,
    'hostname': 'alpha',
    'version': '2.7.0-1649ec00',
    'virtual_ipv4': {
      'address': {'addr': _ipv4('10.144.0.2')},
    },
    'stun_info': {'udp_nat_type': 'Unknown'},
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
