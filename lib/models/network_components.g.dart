// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_components.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProxyNetwork _$ProxyNetworkFromJson(Map<String, dynamic> json) => ProxyNetwork(
  cidr: json['cidr'] as String,
  mappedCidr: json['mappedCidr'] as String?,
  allow: (json['allow'] as List<dynamic>?)?.map((e) => e as String) ?? const [],
);

Map<String, dynamic> _$ProxyNetworkToJson(ProxyNetwork instance) =>
    <String, dynamic>{
      'cidr': instance.cidr,
      'mappedCidr': instance.mappedCidr,
      'allow': instance.allow,
    };

PortForward _$PortForwardFromJson(Map<String, dynamic> json) => PortForward(
  protocol: json['protocol'] as String,
  bindAddress: json['bindAddress'] as String,
  destinationAddress: json['destinationAddress'] as String,
);

Map<String, dynamic> _$PortForwardToJson(PortForward instance) =>
    <String, dynamic>{
      'protocol': instance.protocol,
      'bindAddress': instance.bindAddress,
      'destinationAddress': instance.destinationAddress,
    };

VpnPortalClient _$VpnPortalClientFromJson(Map<String, dynamic> json) =>
    VpnPortalClient(
      name: json['name'] as String,
      virtualIp: json['virtualIp'] as String,
      groups:
          (json['groups'] as List<dynamic>?)?.map((e) => e as String) ??
          const [],
    );

Map<String, dynamic> _$VpnPortalClientToJson(VpnPortalClient instance) =>
    <String, dynamic>{
      'name': instance.name,
      'virtualIp': instance.virtualIp,
      'groups': instance.groups,
    };

VpnPortal _$VpnPortalFromJson(Map<String, dynamic> json) => VpnPortal(
  wireguardListen: json['wireguardListen'] as String,
  wireguardPrivateKey: json['wireguardPrivateKey'] as String?,
  clients:
      (json['clients'] as List<dynamic>?)?.map(
        (e) => VpnPortalClient.fromJson(e as Map<String, dynamic>),
      ) ??
      const [],
);

Map<String, dynamic> _$VpnPortalToJson(VpnPortal instance) => <String, dynamic>{
  'wireguardListen': instance.wireguardListen,
  'wireguardPrivateKey': instance.wireguardPrivateKey,
  'clients': instance.clients.map((e) => e.toJson()).toList(),
};

SecureMode _$SecureModeFromJson(Map<String, dynamic> json) => SecureMode(
  enabled: json['enabled'] as bool? ?? true,
  localPrivateKey: json['localPrivateKey'] as String?,
  localPublicKey: json['localPublicKey'] as String?,
);

Map<String, dynamic> _$SecureModeToJson(SecureMode instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'localPrivateKey': instance.localPrivateKey,
      'localPublicKey': instance.localPublicKey,
    };

ManagedCredential _$ManagedCredentialFromJson(
  Map<String, dynamic> json,
) => ManagedCredential(
  id: json['id'] as String,
  secret: json['secret'] as String,
  expiryUnix: (json['expiryUnix'] as num).toInt(),
  groups:
      (json['groups'] as List<dynamic>?)?.map((e) => e as String) ?? const [],
  allowRelay: json['allowRelay'] as bool? ?? false,
  allowedProxyCidrs:
      (json['allowedProxyCidrs'] as List<dynamic>?)?.map((e) => e as String) ??
      const [],
  reusable: json['reusable'] as bool? ?? true,
);

Map<String, dynamic> _$ManagedCredentialToJson(ManagedCredential instance) =>
    <String, dynamic>{
      'id': instance.id,
      'secret': instance.secret,
      'expiryUnix': instance.expiryUnix,
      'groups': instance.groups,
      'allowRelay': instance.allowRelay,
      'allowedProxyCidrs': instance.allowedProxyCidrs,
      'reusable': instance.reusable,
    };
