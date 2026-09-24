import 'dart:io';

String nodeHost(Uri uri) => uri.host.isNotEmpty ? uri.host : uri.path;

void validateCidr(String value, String name) {
  final parts = value.split('/');
  if (parts.length != 2) {
    throw ArgumentError.value(value, name, 'Must use CIDR format');
  }
  final address = InternetAddress.tryParse(parts.first);
  final prefix = int.tryParse(parts.last);
  final maxPrefix = address?.type == InternetAddressType.IPv6 ? 128 : 32;
  if (address == null || prefix == null || prefix < 0 || prefix > maxPrefix) {
    throw ArgumentError.value(value, name, 'Must use a valid CIDR');
  }
}

void validateSocketAddress(String value, String name) {
  final uri = Uri.tryParse('socket://$value');
  if (uri == null ||
      uri.host.isEmpty ||
      !uri.hasPort ||
      uri.port < 1 ||
      uri.port > 65535) {
    throw ArgumentError.value(value, name, 'Must use a valid socket address');
  }
}

void validatePortableMap(Map<String, Object?>? value, String name) {
  if (value == null) {
    return;
  }
  for (final entry in value.entries) {
    if (entry.key.trim().isEmpty) {
      throw ArgumentError.value(entry.key, name, 'Key name cannot be empty');
    }
    validatePortableValue(entry.value, name);
  }
}

void validatePortableValue(Object? value, String name) {
  if (value == null) {
    throw ArgumentError.value(value, name, 'TOML field cannot use null');
  }
  if (value is num) {
    if (value is double && !value.isFinite) {
      throw ArgumentError.value(value, name, 'Value must be finite');
    }
    return;
  }
  if (value is String || value is bool) {
    return;
  }
  if (value is List<Object?>) {
    for (final item in value) {
      validatePortableValue(item, name);
    }
    return;
  }
  if (value is Map<String, Object?>) {
    validatePortableMap(value, name);
    return;
  }
  throw ArgumentError.value(
    value,
    name,
    'Contains values that cannot be serialized',
  );
}

Map<String, Object?> freezeMap(Map<String, Object?> value) => Map.unmodifiable({
  for (final entry in value.entries) entry.key: _freezeValue(entry.value),
});

Object? _freezeValue(Object? value) {
  if (value is Map<String, Object?>) {
    return freezeMap(value);
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_freezeValue));
  }
  return value;
}
