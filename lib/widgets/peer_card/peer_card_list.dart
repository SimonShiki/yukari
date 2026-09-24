import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'peer_card.dart';
import 'peer_card_data.dart';

class PeerCardList extends StatelessWidget {
  const PeerCardList({
    super.key,
    required this.peers,
    this.listPadding,
  });

  final List<PeerCardData> peers;
  final EdgeInsets? listPadding;

  @override
  Widget build(BuildContext context) {
    return M3ESegmentedList.builder(
      itemCount: peers.length,
      listPadding: listPadding ?? const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemBuilder: (context, index) {
        final peer = peers[index];
        return PeerCard(data: peer);
      },
    );
  }
}
