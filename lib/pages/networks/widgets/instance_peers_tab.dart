import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_instance_controller.dart';
import '../../../widgets/empty_state/empty_state.dart';
import '../../../widgets/peer_card/peer_card_data.dart';
import '../../../widgets/peer_card/peer_card_list.dart';

class InstancePeersTab extends StatelessWidget {
  const InstancePeersTab({super.key, required this.controller});

  final NetworkInstanceController controller;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final instance = controller.instance.value;
      if (!controller.loaded.value) {
        return const Center(child: M3ELoadingIndicator());
      }
      if (instance == null) {
        return const EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Not running',
          message: 'Start the network to see its peers.',
        );
      }
      if (instance.peers.isEmpty && instance.myself == null) {
        return const EmptyState(
          icon: Icons.group_outlined,
          title: 'No peers yet',
          message: 'Peers appear here once they connect.',
        );
      }
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: PeerCardList(
            peers: [
              if (instance.myself case final self?) PeerCardData.fromSelf(self),
              ...instance.peers.map(PeerCardData.fromPeer),
            ],
          ),
        ),
      );
    },
  );
}
