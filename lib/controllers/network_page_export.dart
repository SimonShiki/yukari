part of 'network_page_actions.dart';

/// The export half of the networks page's file round trip.
extension NetworkPageExport on NetworkPageController {
  /// Writes network [id]'s raw EasyTier TOML where the user chooses to save
  /// it, whatever state the network is in.
  Future<void> exportConfig(String id) async {
    final network = saved.networks.peek()[id];
    if (network == null || isDisposed) return;
    try {
      final written = await (saveExportFile ?? _saveTomlFile)(
        exportFileName(network.networkName),
        network.toEasyTierToml(),
      );
      // The save dialog can outlive the page, so the answer is only reported
      // while there is still a page to show it.
      if (written && !isDisposed) showMessage(l10n.value.controllerExported);
    } catch (error) {
      if (!isDisposed) {
        showMessage(l10n.value.controllerExportFailed('$error'));
      }
    }
  }
}

/// The file name an export suggests: the network's name with the characters no
/// file system accepts replaced, so the save dialog can take it.
String exportFileName(String networkName) =>
    '${networkName.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')}.toml';

/// The save dialog the app uses; tests inject `saveExportFile`.
Future<bool> _saveTomlFile(String name, String content) => saveTextFile(
  name,
  content,
  mimeType: 'application/toml',
  dialogTitle: l10n.value.controllerSaveConfig,
);
