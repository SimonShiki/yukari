import 'package:json_annotation/json_annotation.dart';

part 'network_components.g.dart';

@JsonSerializable()
final class ProxyNetwork {
  ProxyNetwork({required this.cidr, this.mappedCidr, this.allow = const []});

  String cidr;
  String? mappedCidr;
  List<String> allow;

  factory ProxyNetwork.fromJson(Map<String, dynamic> json) =>
      _$ProxyNetworkFromJson(json);

  Map<String, dynamic> toJson() => _$ProxyNetworkToJson(this);
}

@JsonSerializable()
final class PortForward {
  PortForward({
    required this.protocol,
    required this.bindAddress,
    required this.destinationAddress,
  });

  String protocol;
  String bindAddress;
  String destinationAddress;

  factory PortForward.fromJson(Map<String, dynamic> json) =>
      _$PortForwardFromJson(json);

  Map<String, dynamic> toJson() => _$PortForwardToJson(this);
}

@JsonSerializable()
final class VpnPortalClient {
  VpnPortalClient({
    required this.name,
    required this.virtualIp,
    this.groups = const [],
  });

  String name;
  String virtualIp;
  List<String> groups;

  factory VpnPortalClient.fromJson(Map<String, dynamic> json) =>
      _$VpnPortalClientFromJson(json);

  Map<String, dynamic> toJson() => _$VpnPortalClientToJson(this);
}

@JsonSerializable(explicitToJson: true)
final class VpnPortal {
  VpnPortal({
    required this.wireguardListen,
    this.wireguardPrivateKey,
    this.clients = const [],
  });

  String wireguardListen;
  String? wireguardPrivateKey;
  List<VpnPortalClient> clients;

  factory VpnPortal.fromJson(Map<String, dynamic> json) =>
      _$VpnPortalFromJson(json);

  Map<String, dynamic> toJson() => _$VpnPortalToJson(this);
}

@JsonSerializable()
final class SecureMode {
  SecureMode({this.enabled = true, this.localPrivateKey, this.localPublicKey});

  bool enabled;
  String? localPrivateKey;
  String? localPublicKey;

  factory SecureMode.fromJson(Map<String, dynamic> json) =>
      _$SecureModeFromJson(json);

  Map<String, dynamic> toJson() => _$SecureModeToJson(this);
}

@JsonSerializable()
final class ManagedCredential {
  ManagedCredential({
    required this.id,
    required this.secret,
    required this.expiryUnix,
    this.groups = const [],
    this.allowRelay = false,
    this.allowedProxyCidrs = const [],
    this.reusable = true,
  });

  String id;
  String secret;
  int expiryUnix;
  List<String> groups;
  bool allowRelay;
  List<String> allowedProxyCidrs;
  bool reusable;

  factory ManagedCredential.fromJson(Map<String, dynamic> json) =>
      _$ManagedCredentialFromJson(json);

  Map<String, dynamic> toJson() => _$ManagedCredentialToJson(this);
}
