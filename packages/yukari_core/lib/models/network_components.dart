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
    this.enabled = true,
  });

  /// Disabling keeps the portal's address, key and clients for later.
  bool enabled;
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

@JsonSerializable(explicitToJson: true)
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

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum DnsRecordType {
  a('A'),
  aaaa('AAAA'),
  aname('ANAME'),
  caa('CAA'),
  cert('CERT'),
  cname('CNAME'),
  csync('CSYNC'),
  hinfo('HINFO'),
  https('HTTPS'),
  mx('MX'),
  naptr('NAPTR'),
  ns('NS'),
  openpgpkey('OPENPGPKEY'),
  ptr('PTR'),
  soa('SOA'),
  srv('SRV'),
  sshfp('SSHFP'),
  svcb('SVCB'),
  tlsa('TLSA'),
  txt('TXT');

  const DnsRecordType(this.wireName);

  final String wireName;

  static DnsRecordType? tryParse(String value) {
    final normalized = value.trim().toUpperCase();
    for (final type in DnsRecordType.values) {
      if (type.wireName == normalized) return type;
    }
    return null;
  }
}

@JsonSerializable()
final class DnsRecord {
  DnsRecord({
    required this.name,
    required this.type,
    required this.value,
    this.ttl,
  });

  String name;
  DnsRecordType type;
  String value;
  int? ttl;

  factory DnsRecord.fromJson(Map<String, dynamic> json) =>
      _$DnsRecordFromJson(json);

  Map<String, dynamic> toJson() => _$DnsRecordToJson(this);
}

@JsonSerializable(explicitToJson: true)
final class DnsZone {
  DnsZone({
    required this.origin,
    this.ttl,
    this.records = const [],
  });

  String origin;
  int? ttl;
  List<DnsRecord> records;

  factory DnsZone.fromJson(Map<String, dynamic> json) =>
      _$DnsZoneFromJson(json);

  Map<String, dynamic> toJson() => _$DnsZoneToJson(this);
}

@JsonSerializable(explicitToJson: true)
final class DnsConfig {
  DnsConfig({this.domain, this.zones = const []});

  String? domain;
  List<DnsZone> zones;

  factory DnsConfig.fromJson(Map<String, dynamic> json) =>
      _$DnsConfigFromJson(json);

  Map<String, dynamic> toJson() => _$DnsConfigToJson(this);
}
