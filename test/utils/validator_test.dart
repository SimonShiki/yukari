import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/models/network.dart';
import 'package:yukari/utils/validator.dart';

void main() {
  test('network name must be non-empty and unique', () {
    expect(validateNetworkName('alpha', ['beta']), isNull);
    expect(validateNetworkName('  ', []), isNotNull);
    expect(validateNetworkName('beta', ['beta']), isNotNull);
    expect(validateNetworkName(' beta ', ['beta']), isNotNull);
  });

  test('hostname is limited to 32 characters', () {
    expect(validateHostname(''), isNull);
    expect(validateHostname('a' * 32), isNull);
    expect(validateHostname('a' * 33), isNotNull);
  });

  test('CIDR must match the address family', () {
    const v4 = InternetAddressType.IPv4;
    const v6 = InternetAddressType.IPv6;
    expect(validateCidr('', v4), isNull);
    expect(validateCidr('10.144.144.1/24', v4), isNull);
    expect(validateCidr('10.144.144.1', v4), isNotNull);
    expect(validateCidr('10.144.144.1/33', v4), isNotNull);
    expect(validateCidr('300.1.1.1/24', v4), isNotNull);
    expect(validateCidr('fd00::1/64', v4), isNotNull);
    expect(validateCidr('fd00::1/64', v6), isNull);
    expect(validateCidr('fd00::1/129', v6), isNotNull);
    expect(validateCidr('10.0.0.1/8', v6), isNotNull);
  });

  test('integer ranges reject non-numbers and out-of-range values', () {
    expect(validatePort('11010'), isNull);
    expect(validatePort(''), isNotNull);
    expect(validatePort('0'), isNotNull);
    expect(validatePort('65536'), isNotNull);
    expect(validatePort('abc'), isNotNull);
    expect(validateIntRange('576', 'MTU', 576, 65535), isNull);
    expect(validateIntRange('575', 'MTU', 576, 65535), isNotNull);
  });

  test('hosts are IP addresses or DNS names', () {
    expect(validateHost('0.0.0.0'), isNull);
    expect(validateHost('::'), isNull);
    expect(validateHost('example.com'), isNull);
    expect(validateHost(''), isNotNull);
    expect(validateHost('exa mple.com'), isNotNull);
    expect(validateHost('-bad.com'), isNotNull);
    expect(validateHost('a/b'), isNotNull);
  });

  test('node URLs carry a host but no port, query or fragment', () {
    expect(validateNodeUrl('example.com'), isNull);
    expect(validateNodeUrl('wss://example.com/path'), isNull);
    expect(validateNodeUrl('1.2.3.4'), isNull);
    expect(validateNodeUrl(''), isNotNull);
    expect(validateNodeUrl('example.com:11010'), isNotNull);
    expect(validateNodeUrl('tcp://example.com:11010'), isNotNull);
    expect(validateNodeUrl('example.com?a=b'), isNotNull);
    expect(validateNodeUrl('example.com/path'), isNotNull);
  });

  test('SOCKS5 proxy needs scheme, host and port', () {
    expect(validateSocks5Proxy(''), isNull);
    expect(validateSocks5Proxy('socks5://127.0.0.1:1080'), isNull);
    expect(validateSocks5Proxy('socks5://127.0.0.1'), isNotNull);
    expect(validateSocks5Proxy('http://127.0.0.1:1080'), isNotNull);
    expect(validateSocks5Proxy('127.0.0.1:1080'), isNotNull);
  });

  test('STUN servers are validated line by line', () {
    expect(validateStunServers(''), isNull);
    expect(validateStunServers('stun.example.com:3478\n\n1.2.3.4'), isNull);
    expect(validateStunServers('[::1]:3478'), isNull);
    expect(validateStunServers('stun.example.com:99999'), isNotNull);
    expect(validateStunServers('ok.com\nbad host'), contains('bad host'));
  });

  test('private keys are base64-encoded 32-byte values', () {
    expect(validatePrivateKey(''), isNull);
    expect(validatePrivateKey('A' * 43 + '='), isNull);
    expect(validatePrivateKey('AAAA'), isNotNull);
    expect(validatePrivateKey('not base64!'), isNotNull);
  });

  test('whole networks are checked with the same rules as the editor', () {
    expect(validateNetwork(Network()), isNull);
    expect(validateNetwork(Network()..ipv4 = 'not-an-ip'), isNotNull);
    expect(validateNetwork(Network()..flags.mtu = 10), isNotNull);
    expect(validateNetwork(Network()..stunServers = ['bad host']), isNotNull);
  });
}
