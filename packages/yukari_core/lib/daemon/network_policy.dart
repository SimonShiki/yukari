import 'package:toml/toml.dart';

import '../models/models.dart';
import '../utils/easytier_config_serializer.dart';

/// EasyTier settings that name files root reads or writes, or open EasyTier's
/// management RPC. The user edits networks.json freely, and the service runs
/// EasyTier as root, so these would reach past the network the user controls.
const privilegedSettings = {
  'credential_file',
  'file_logger',
  'rpc_portal',
  'rpc_portal_whitelist',
};

/// A network namespace name; EasyTier joins `/var/run/netns/<name>`.
final _namespace = RegExp(r'^(?!\.\.?$)[A-Za-z0-9_.-]+$');

/// Why the service must not run [network] with root's privileges, or null
/// when it may.
///
/// Reads the configuration EasyTier receives, so free-form additions are
/// checked the same as the fields Yukari models.
String? privilegedSetting(Network network) {
  final config = TomlDocument.parse(network.toEasyTierToml()).toMap();
  for (final key in privilegedSettings) {
    if (config.containsKey(key)) return 'it sets $key';
  }
  final namespace = config['netns'];
  if (namespace != null &&
      (namespace is! String || !_namespace.hasMatch(namespace))) {
    return 'its network namespace is not a plain name';
  }
  return null;
}
