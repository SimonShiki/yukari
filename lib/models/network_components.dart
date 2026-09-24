import 'package:json_annotation/json_annotation.dart';

import '../utils/validator.dart';

part 'network_components.g.dart';

@JsonSerializable()
final class ProxyNetwork {
  ProxyNetwork({
    required this.cidr,
    this.mappedCidr,
    Iterable<String> allow = const [],
  }) : allow = List.unmodifiable(allow) {
    validateCidr(cidr, 'cidr');
    if (mappedCidr != null) {
      validateCidr(mappedCidr!, 'mappedCidr');
    }
  }

  final String cidr;
  final String? mappedCidr;
  final List<String> allow;

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
  }) {
    final normalizedProtocol = protocol.toLowerCase();
    if (normalizedProtocol != 'tcp' && normalizedProtocol != 'udp') {
      throw ArgumentError.value(
        protocol,
        'protocol',
        'Only supports "tcp" or "udp"',
      );
    }
    validateSocketAddress(bindAddress, 'bindAddress');
    validateSocketAddress(destinationAddress, 'destinationAddress');
  }

  final String protocol;
  final String bindAddress;
  final String destinationAddress;

  factory PortForward.fromJson(Map<String, dynamic> json) =>
      _$PortForwardFromJson(json);

  Map<String, dynamic> toJson() => _$PortForwardToJson(this);
}

@JsonSerializable()
final class VpnPortalClient {
  VpnPortalClient({
    required this.name,
    required this.virtualIp,
    Iterable<String> groups = const [],
  }) : groups = List.unmodifiable(groups) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Cannot be empty');
    }
    validateCidr(virtualIp, 'virtualIp');
  }

  final String name;
  final String virtualIp;
  final List<String> groups;

  factory VpnPortalClient.fromJson(Map<String, dynamic> json) =>
      _$VpnPortalClientFromJson(json);

  Map<String, dynamic> toJson() => _$VpnPortalClientToJson(this);
}

@JsonSerializable(explicitToJson: true)
final class VpnPortal {
  VpnPortal({
    required this.wireguardListen,
    this.wireguardPrivateKey,
    Iterable<VpnPortalClient> clients = const [],
  }) : clients = List.unmodifiable(clients) {
    validateSocketAddress(wireguardListen, 'wireguardListen');
    if (wireguardPrivateKey != null && wireguardPrivateKey!.isEmpty) {
      throw ArgumentError.value(
        wireguardPrivateKey,
        'wireguardPrivateKey',
        'Cannot be an empty string',
      );
    }
  }

  final String wireguardListen;
  final String? wireguardPrivateKey;
  final List<VpnPortalClient> clients;

  factory VpnPortal.fromJson(Map<String, dynamic> json) =>
      _$VpnPortalFromJson(json);

  Map<String, dynamic> toJson() => _$VpnPortalToJson(this);
}

@JsonSerializable()
final class SecureMode {
  SecureMode({this.enabled = true, this.localPrivateKey, this.localPublicKey});

  final bool enabled;
  final String? localPrivateKey;
  final String? localPublicKey;

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
    Iterable<String> groups = const [],
    this.allowRelay = false,
    Iterable<String> allowedProxyCidrs = const [],
    this.reusable = true,
  }) : groups = List.unmodifiable(groups),
       allowedProxyCidrs = List.unmodifiable(allowedProxyCidrs) {
    if (id.trim().isEmpty || secret.isEmpty) {
      throw ArgumentError(
        'The id and secret of a managed credential cannot be empty.',
      );
    }
  }

  final String id;
  final String secret;
  final int expiryUnix;
  final List<String> groups;
  final bool allowRelay;
  final List<String> allowedProxyCidrs;
  final bool reusable;

  factory ManagedCredential.fromJson(Map<String, dynamic> json) =>
      _$ManagedCredentialFromJson(json);

  Map<String, dynamic> toJson() => _$ManagedCredentialToJson(this);
}
