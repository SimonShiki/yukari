import 'dart:async';

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/about_controller.dart';
import '../../l10n/l10n.dart';
import '../../widgets/link_list/link_list.dart';
import '../../widgets/snackbar/app_snackbar.dart';

/// The app icon declared in pubspec for the launcher.
const String _logoAsset = 'assets/generated/yukari-with-background-1024.png';

/// The product name: a brand, so it is not translated.
const String _appName = 'Yukari';

/// How wide the content grows before it stops, keeping the page readable on a
/// desktop window.
const double _maxWidth = 560;

/// About Yukari: the app icon and version, its source code, and its licenses.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.controller});

  /// Injected by tests; the page creates and disposes its own otherwise.
  final AboutController? controller;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final AboutController _controller =
      widget.controller ?? _createController();

  AboutController _createController() => AboutController(
    showMessage: (message) => showAppSnackBar(context, message),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.loadVersion());
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _openLicenses() => showLicensePage(
    context: context,
    applicationName: _appName,
    applicationVersion: _controller.version.value,
    applicationIcon: const _AppLogo(size: 40),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Centered, and scrollable when a short window cannot fit it.
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: _Branding(controller: _controller),
                      ),
                    ),
                  ),
                  LinkList(
                    entries: [
                      LinkListEntry(
                        // GitHub's mark is not in the Material icon font; the
                        // source-code icon names the link just as clearly.
                        icon: const Icon(Icons.code_rounded),
                        label: l10n.aboutSourceCode,
                        onTap: _controller.openSourceCode,
                      ),
                      LinkListEntry(
                        icon: const Icon(Icons.description_outlined),
                        label: l10n.aboutLicenses,
                        onTap: _openLicenses,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's identity, centered: its icon, name, and version once known.
class _Branding extends StatelessWidget {
  const _Branding({required this.controller});

  final AboutController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _AppLogo(),
        const SizedBox(height: 24),
        Text(_appName, style: theme.emphasizedTextTheme.headlineSmall),
        const SizedBox(height: 4),
        // Only the version line subscribes, so loading it rebuilds nothing else.
        SignalBuilder(
          builder: (context) {
            final version = controller.version.value;
            if (version == null) return const SizedBox.shrink();
            return Text(
              context.l10n.aboutVersion(version),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The app icon, in the asset's own rounded app-icon shape.
class _AppLogo extends StatelessWidget {
  const _AppLogo({this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Image.asset(_logoAsset, width: size, height: size);
}
