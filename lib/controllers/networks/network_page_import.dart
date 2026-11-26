part of 'network_page_actions.dart';

final _importQueue = MutationQueue();

/// The import half of the networks page's file round trip.
extension NetworkPageImport on NetworkPageController {
  /// Imports a TOML config the user picked as a new network.
  Future<void> importFromFile() async {
    final picked = await readPickedConfig(pickConfig, showMessage);
    if (picked == null || isDisposed) return;
    final error = await _saveImportedConfig(picked);
    if (error != null && !isDisposed) showMessage(error);
  }

  /// Imports `.toml` config files dropped onto the networks page.
  Future<void> importDroppedFiles(List<String> paths) async {
    setDraggingConfig(false);
    if (isDisposed) return;
    final filePaths = [
      for (final path in paths)
        if (p.isAbsolute(path)) path,
    ];
    if (filePaths.isEmpty) {
      showMessage(l10n.value.controllerImportDropTomlOnly);
      return;
    }
    if (filePaths.length == 1) {
      final error = await _tryImportDropped(filePaths.single);
      if (error != null && !isDisposed) showMessage(error);
      return;
    }
    var imported = 0;
    var failed = 0;
    for (final path in filePaths) {
      if (isDisposed) return;
      final error = await _tryImportDropped(path);
      if (isDisposed) return;
      if (error == null) {
        imported++;
      } else {
        failed++;
      }
    }
    if (isDisposed) return;
    showMessage(switch ((imported, failed)) {
      (_, 0) => l10n.value.controllerImportBatchSuccess(imported),
      (0, _) => l10n.value.controllerImportBatchFailed(failed),
      _ => l10n.value.controllerImportBatchPartial(imported, failed),
    });
  }

  Future<String?> _saveImportedConfig(PickedConfig picked) =>
      _importQueue.enqueue(() async {
        if (isDisposed) return null;
        try {
          final network = parseImportedConfig(picked.content, validateConfig);
          await saved.addNetwork(const Uuid().v4(), network);
          return null;
        } on _InvalidConfig catch (error) {
          return l10n.value.controllerImportInvalid(picked.name, error.message);
        } catch (error) {
          return l10n.value.controllerImportFailed('$error');
        }
      });

  Future<String?> _tryImportDropped(String path) async {
    final name = p.basename(path);
    if (p.extension(path).toLowerCase() != '.toml') {
      return l10n.value.controllerImportNotToml(name);
    }
    final PickedConfig picked;
    try {
      final bytes = await readFileAtPath(
        path,
        maxBytes: maxImportedConfigBytes,
      );
      picked = PickedConfig(name: name, content: utf8.decode(bytes));
    } catch (error) {
      if (error is FileTooLargeException || error is FormatException) {
        return l10n.value.controllerImportInvalid(name, '$error');
      }
      return l10n.value.controllerFileUnavailable;
    }
    return _saveImportedConfig(picked);
  }
}

class _InvalidPickedConfig implements Exception {
  _InvalidPickedConfig(this.name, this.message);

  final String name;
  final String message;
}

/// Reads the picked config, reporting a file that cannot be read.
Future<PickedConfig?> readPickedConfig(
  Future<PickedConfig?> Function()? pick,
  void Function(String message) showMessage,
) async {
  try {
    return await (pick ?? _pickTomlFile)();
  } on FileTooLargeException catch (error) {
    showMessage(l10n.value.controllerImportInvalid(error.name, '$error'));
    return null;
  } on _InvalidPickedConfig catch (error) {
    showMessage(l10n.value.controllerImportInvalid(error.name, error.message));
    return null;
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

/// The largest config file an import reads; real configs are a few KiB.
const int maxImportedConfigBytes = 1024 * 1024;

/// The picker the app uses; tests inject `pickConfig`.
Future<PickedConfig?> _pickTomlFile() async {
  final file = await FilePicker.pickFile(
    dialogTitle: l10n.value.controllerSelectConfig,
    type: FileType.custom,
    allowedExtensions: const ['toml'],
  );
  if (file == null) return null;
  final bytes = await readPickedFile(file, maxBytes: maxImportedConfigBytes);
  try {
    return PickedConfig(name: file.name, content: utf8.decode(bytes));
  } on FormatException catch (error) {
    throw _InvalidPickedConfig(file.name, '$error');
  }
}
