import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/qr_share_send_controller.dart';
import '../../l10n/l10n.dart';
import '../../share/share_document.dart';
import '../../share/share_targets.dart';
import '../../utils/file_save.dart';
import '../../widgets/empty_state/empty_state.dart';
import '../../widgets/snackbar/app_snackbar.dart';
import 'widgets/qr_share_summary_card.dart';
import 'widgets/share_extra_options.dart';
import 'widgets/share_page_body.dart';
import 'widgets/qr_stream_card.dart';
import 'widgets/qr_stream_settings.dart';

/// Shows a masked saved network or node as a fountain-coded QR stream, so the
/// other device can scan it in.
class QrShareSendPage extends StatefulWidget {
  const QrShareSendPage({
    super.key,
    required this.kind,
    required this.ids,
    this.controller,
  });

  /// Whether [ids] name saved networks or bookmarks.
  final ShareKind kind;

  /// The saved networks' or bookmarks' ids, in the order they are shared.
  final List<String> ids;

  /// A controller for tests; the page resolves and owns its own otherwise.
  final QrShareSendController? controller;

  @override
  State<QrShareSendPage> createState() => _QrShareSendPageState();
}

class _QrShareSendPageState extends State<QrShareSendPage>
    with WidgetsBindingObserver {
  QrShareSendController? _own;
  ShareUnavailableReason? _unavailable;

  QrShareSendController? get _controller => widget.controller ?? _own;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final target = resolveShareItems(widget.kind, widget.ids);
    if (target.documents.isEmpty) {
      _unavailable = target.reason ?? ShareUnavailableReason.unsupported;
      return;
    }
    final controller = QrShareSendController(
      documents: target.documents,
      refreshRate: View.of(context).display.refreshRate,
      extras: target.extras,
      resolve: (options) =>
          resolveShareItems(widget.kind, widget.ids, options: options),
    );
    // The page owns this controller, so it starts the stream: opening the share
    // is the user asking to send, not asking to press play first.
    controller.play();
    _own = controller;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A backgrounded page keeps no stream running; the user plays it again.
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _controller?.pause();
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The page stops a stream it did not create; an injected controller stays
    // its owner's to dispose.
    _controller?.pause();
    _own?.dispose();
    super.dispose();
  }

  /// Encodes the stream as a GIF and saves it where the user chooses.
  Future<void> _exportGif() async {
    final controller = _controller;
    if (controller == null || controller.exporting.value) return;
    try {
      final bytes = await controller.exportGif();
      if (bytes == null || !mounted) return;
      final written = await saveBytesFile(
        'yukari-share.gif',
        bytes,
        mimeType: 'image/gif',
      );
      // A dismissed save dialog says nothing: the user chose not to save it.
      if (written && mounted) {
        showAppSnackBar(context, context.l10n.shareQrGifSaved);
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, context.l10n.shareQrGifFailed('$error'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.shareSendTitle)),
      body: controller == null
          ? _unavailableState(context)
          : _content(controller),
    );
  }

  Widget _content(QrShareSendController controller) => SharePageBody(
    // One builder for everything a share option rewrites: the summary says what
    // the documents carry, so it moves with them. The stream itself keeps its
    // own builders, so a frame never rebuilds this column.
    child: SignalBuilder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          QrShareSummaryCard(documents: controller.documents.value),
          ShareExtraOptions(controller: controller),
          QrStreamCard(controller: controller),
          QrStreamSettings(controller: controller, onExportGif: _exportGif),
        ],
      ),
    ),
  );

  /// What the page shows when there is nothing to stream.
  Widget _unavailableState(BuildContext context) {
    final l10n = context.l10n;
    final (icon, message) = switch (_unavailable!) {
      ShareUnavailableReason.networkMissing => (
        Icons.link_off,
        l10n.shareSendNetworkMissing,
      ),
      ShareUnavailableReason.bookmarkMissing => (
        Icons.link_off,
        l10n.shareSendNodeMissing,
      ),
      ShareUnavailableReason.networkWithoutPeers => (
        Icons.hub_outlined,
        l10n.shareSendNoPeers,
      ),
      ShareUnavailableReason.unsupported => (
        Icons.qr_code_2,
        l10n.shareSendUnsupported,
      ),
    };
    return EmptyState(icon: icon, title: l10n.shareSendTitle, message: message);
  }
}
