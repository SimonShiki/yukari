import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/qr_share_send_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/card_surface/card_surface.dart';
import '../../../widgets/form_section/form_segments.dart';

/// What a network share can carry besides its peers, one switch each.
///
/// Both start off, so the share is exactly the peers and secret it always was
/// until the user opts in. The card is absent when the target can offer
/// neither, and a row is absent when its own option is unavailable.
class ShareExtraOptions extends StatelessWidget {
  const ShareExtraOptions({super.key, required this.controller});

  /// The sender whose options, availability and export state it shows.
  final QrShareSendController controller;

  @override
  Widget build(BuildContext context) {
    final selfPeer = controller.selfPeerAvailable;
    final configs = controller.configsAvailable;
    if (!selfPeer && !configs) return const SizedBox.shrink();
    final l10n = context.l10n;
    return CardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selfPeer)
            SignalBuilder(
              builder: (context) => SwitchSegment(
                icon: Icons.devices_outlined,
                title: l10n.shareSendIncludeSelf,
                subtitle: l10n.shareSendIncludeSelfHint,
                value: controller.includeSelf.value,
                // The export encodes the share it started with.
                enabled: !controller.exporting.value,
                onChanged: controller.setIncludeSelf,
              ),
            ),
          if (configs)
            SignalBuilder(
              builder: (context) => SwitchSegment(
                icon: Icons.tune_rounded,
                title: l10n.shareSendIncludeConfigs,
                subtitle: l10n.shareSendIncludeConfigsHint,
                value: controller.includeConfigs.value,
                enabled: !controller.exporting.value,
                onChanged: controller.setIncludeConfigs,
              ),
            ),
        ],
      ),
    );
  }
}
