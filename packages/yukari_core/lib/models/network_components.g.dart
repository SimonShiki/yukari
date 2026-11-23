// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_components.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProxyNetwork _$ProxyNetworkFromJson(Map<String, dynamic> json) => ProxyNetwork(
  cidr: json['cidr'] as String,
  mappedCidr: json['mappedCidr'] as String?,
  allow:
      (json['allow'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
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
          (json['groups'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
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
      (json['clients'] as List<dynamic>?)
          ?.map((e) => VpnPortalClient.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  enabled: json['enabled'] as bool? ?? true,
);

Map<String, dynamic> _$VpnPortalToJson(VpnPortal instance) => <String, dynamic>{
  'enabled': instance.enabled,
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

ManagedCredential _$ManagedCredentialFromJson(Map<String, dynamic> json) =>
    ManagedCredential(
      id: json['id'] as String,
      secret: json['secret'] as String,
      expiryUnix: (json['expiryUnix'] as num).toInt(),
      groups:
          (json['groups'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      allowRelay: json['allowRelay'] as bool? ?? false,
      allowedProxyCidrs:
          (json['allowedProxyCidrs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
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

DnsRecord _$DnsRecordFromJson(Map<String, dynamic> json) => DnsRecord(
  name: json['name'] as String,
  type: $enumDecode(_$DnsRecordTypeEnumMap, json['type']),
  value: json['value'] as String,
  ttl: (json['ttl'] as num?)?.toInt(),
);

Map<String, dynamic> _$DnsRecordToJson(DnsRecord instance) => <String, dynamic>{
  'name': instance.name,
  'type': _$DnsRecordTypeEnumMap[instance.type]!,
  'value': instance.value,
  'ttl': instance.ttl,
};

const _$DnsRecordTypeEnumMap = {
  DnsRecordType.a: 'A',
  DnsRecordType.aaaa: 'AAAA',
  DnsRecordType.aname: 'ANAME',
  DnsRecordType.caa: 'CAA',
  DnsRecordType.cert: 'CERT',
  DnsRecordType.cname: 'CNAME',
  DnsRecordType.csync: 'CSYNC',
  DnsRecordType.hinfo: 'HINFO',
  DnsRecordType.https: 'HTTPS',
  DnsRecordType.mx: 'MX',
  DnsRecordType.naptr: 'NAPTR',
  DnsRecordType.ns: 'NS',
  DnsRecordType.openpgpkey: 'OPENPGPKEY',
  DnsRecordType.ptr: 'PTR',
  DnsRecordType.soa: 'SOA',
  DnsRecordType.srv: 'SRV',
  DnsRecordType.sshfp: 'SSHFP',
  DnsRecordType.svcb: 'SVCB',
  DnsRecordType.tlsa: 'TLSA',
  DnsRecordType.txt: 'TXT',
};

DnsZone _$DnsZoneFromJson(Map<String, dynamic> json) => DnsZone(
  origin: json['origin'] as String,
  ttl: (json['ttl'] as num?)?.toInt(),
  records:
      (json['records'] as List<dynamic>?)
          ?.map((e) => DnsRecord.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$DnsZoneToJson(DnsZone instance) => <String, dynamic>{
  'origin': instance.origin,
  'ttl': instance.ttl,
  'records': instance.records.map((e) => e.toJson()).toList(),
};

DnsConfig _$DnsConfigFromJson(Map<String, dynamic> json) => DnsConfig(
  domain: json['domain'] as String?,
  zones:
      (json['zones'] as List<dynamic>?)
          ?.map((e) => DnsZone.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$DnsConfigToJson(DnsConfig instance) => <String, dynamic>{
  'domain': instance.domain,
  'zones': instance.zones.map((e) => e.toJson()).toList(),
};
