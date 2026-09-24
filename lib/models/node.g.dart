// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Node _$NodeFromJson(Map<String, dynamic> json) => Node(
  id: json['id'] as String,
  url: Uri.parse(json['url'] as String),
  port: (json['port'] as num).toInt(),
  protocols: (json['protocols'] as List<dynamic>).map(
    (e) => $enumDecode(_$NodeProtocolEnumMap, e),
  ),
  publicKey: json['publicKey'] as String?,
);

Map<String, dynamic> _$NodeToJson(Node instance) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url.toString(),
  'port': instance.port,
  'protocols': instance.protocols
      .map((e) => _$NodeProtocolEnumMap[e]!)
      .toList(),
  'publicKey': instance.publicKey,
};

const _$NodeProtocolEnumMap = {
  NodeProtocol.tcp: 'tcp',
  NodeProtocol.udp: 'udp',
  NodeProtocol.ws: 'ws',
  NodeProtocol.wss: 'wss',
  NodeProtocol.quic: 'quic',
  NodeProtocol.wg: 'wg',
};
