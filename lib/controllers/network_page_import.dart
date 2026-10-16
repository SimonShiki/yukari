part of 'network_page_actions.dart';

/// Reads the picked config, reporting a file that cannot be read.
Future<PickedConfig?> readPickedConfig(
Future<PickedConfig?> Function()? pick,
void Function(String message) showMessage,
) async {
  try {
    return await (pick ?? _pickTomlFile)();
  } catch (_) {
    showMessage(l10n.value.controllerFileUnavailable);
    return null;
  }
}

/// Parses and validates a config, rejecting what EasyTier or the editor's
/// rules do not accept.
Network parseImportedConfig(
  String content,
  void Function(String config)? validateConfig,
) {
  try {
    if (validateConfig case final validate?) {
      validate(content);
    } else {
      parseConfig(content);
    }
  } catch (error) {
    throw _InvalidConfig('$error');
  }
  final Network network;
  try {
    network = parseEasyTierConfig(content);
  } catch (error) {
    throw _InvalidConfig('$error');
  }
  final invalid =
      validateNetworkName(network.networkName, saved.networkNames()) ??
      validateNetwork(network);
  if (invalid != null) throw _InvalidConfig(invalid);
  return network;
}

/// The picker the app uses; tests inject `pickConfig`.
Future<PickedConfig?> _pickTomlFile() async {
  final file = await FilePicker.pickFile(
    dialogTitle: l10n.value.controllerSelectConfig,
    type: FileType.custom,
    allowedExtensions: const ['toml'],
  );
  final path = file?.path;
  if (file == null || path == null) return null;
  return PickedConfig(
    name: file.name,
    content: await File(path).readAsString(),
  );
}
