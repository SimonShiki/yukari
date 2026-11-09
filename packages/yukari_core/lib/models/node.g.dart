// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Node _$NodeFromJson(Map<String, dynamic> json) => Node(
  name: json['name'] as String,
  url: Uri.parse(json['url'] as String),
  publicKey: json['publicKey'] as String?,
);

Map<String, dynamic> _$NodeToJson(Node instance) => <String, dynamic>{
  'name': instance.name,
  'url': instance.url.toString(),
  'publicKey': instance.publicKey,
};
