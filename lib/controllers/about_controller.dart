import 'package:package_info_plus/package_info_plus.dart';
import 'package:signals/signals.dart';
import 'package:url_launcher/url_launcher.dart';

import '../signals/locale.dart';

/// The About page's state: the installed app version, and the repository link.
///
/// The version lookup and the URL launcher are injected so widget tests never
/// reach the platform plugins; the defaults are package_info_plus and
/// url_launcher. The page only builds widgets and calls these members (AGENTS.md
/// § Architecture).
class AboutController {
  AboutController({
    required this.showMessage,
    Future<String?> Function()? appVersion,
    Future<bool> Function(Uri url)? launch,
  }) : _appVersion = appVersion ?? _installedVersion,
       _launch = launch ?? _launchExternally;

  /// Reports a user-visible outcome; the page shows it in a snackbar.
  final void Function(String message) showMessage;

  final Future<String?> Function() _appVersion;
  final Future<bool> Function(Uri url) _launch;

  /// Where Yukari's source code lives.
  static final Uri repository = Uri.parse(
    'https://github.com/SimonShiki/yukari',
  );

  /// The installed app version, or null while it is unknown or unavailable.
  final version = signal<String?>(null);

  bool _disposed = false;

  /// Reads the app version once, called from the page's initState.
  ///
  /// A version the platform cannot report is no version at all: the page omits
  /// the line instead of showing a placeholder.
  Future<void> loadVersion() async {
    String? loaded;
    try {
      loaded = await _appVersion();
    } catch (_) {
      loaded = null;
    }
    if (_disposed) return;
    final trimmed = loaded?.trim();
    version.value = trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Opens [repository], reporting a failure instead of throwing into the UI.
  Future<void> openSourceCode() async {
    try {
      if (await _launch(repository)) return;
      _fail(repository.toString());
    } catch (error) {
      _fail('$error');
    }
  }

  void _fail(String error) {
    if (_disposed) return;
    showMessage(l10n.value.aboutOpenFailed(error));
  }

  /// Frees the signals this controller owns.
  void dispose() {
    _disposed = true;
    version.dispose();
  }
}

/// The real version lookup, [PackageInfo.fromPlatform].
Future<String?> _installedVersion() async =>
    (await PackageInfo.fromPlatform()).version;

/// The real launcher: hand web links to the platform's browser or app.
Future<bool> _launchExternally(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);
