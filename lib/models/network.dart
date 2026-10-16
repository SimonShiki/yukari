import 'package:json_annotation/json_annotation.dart';

import 'network_flags.dart';
import 'network_components.dart';
import 'node.dart';

part 'network.g.dart';

/// A saved network configuration. Fields are edited in place; validation is
/// the responsibility of whoever writes them (see `utils/validator.dart`).
@JsonSerializable(explicitToJson: true)
final class Network {
  Network(this.networkName);

  factory Network.fromJson(Map<String, dynamic> json) =>
      _$NetworkFromJson(json);

  Map<String, dynamic> toJson() => _$NetworkToJson(this);

  Network copy() => Network.fromJson(toJson());

  String? hostname;
  String networkName;
  String? networkSecret;
  String? netNamespace;
  String? ipv4;
  String? ipv6;
  bool ipv6PublicAddressProvider = false;
  bool ipv6PublicAddressAuto = false;
  String? ipv6PublicAddressPrefix;
  bool dhcp = true;
  List<Node> nodes = [];
  List<Uri> listeners = [];
  List<Uri> mappedListeners = [];
  List<String> exitNodes = [];
  List<ProxyNetwork> proxyNetworks = [];
  VpnPortal? vpnPortal;
  List<String> routes = [];
  Uri? socks5Proxy;
  List<PortForward> portForwards = [];
  SecureMode? secureMode;
  Map<String, Object?>? acl;
  List<String> tcpWhitelist = [];
  List<String> udpWhitelist = [];
  List<String> stunServers = [];
  List<String> tcpStunServers = [];
  List<String> stunServersV6 = [];
  String? credentialFile;
  List<ManagedCredential> managedCredentials = [];
  NetworkFlags flags = NetworkFlags();
  Map<String, Object?> additionalFlags = {};
  Map<String, Object?> additionalConfiguration = {};

  bool autoStart = false;
  DateTime createdAt = DateTime.now().toUtc();
  DateTime updatedAt = DateTime.now().toUtc();
}
