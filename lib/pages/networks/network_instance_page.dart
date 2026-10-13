import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/network_instance_controller.dart';
import '../../l10n/l10n.dart';
import '../../widgets/empty_state/empty_state.dart';
import 'widgets/instance_logs_tab.dart';
import 'widgets/instance_peers_tab.dart';

/// Shows the peers and logs of the running network [id].
class NetworkInstancePage extends StatefulWidget {
  const NetworkInstancePage({
    super.key,
    required this.id,
    this.initialTab = InstanceTab.peers,
    this.tab,
    this.controller,
  });

  final String id;
  final InstanceTab initialTab;

  /// The shown tab, kept in sync both ways. Takes over [initialTab].
  final Signal<InstanceTab>? tab;
  final NetworkInstanceController? controller;

  @override
  State<NetworkInstancePage> createState() => _NetworkInstancePageState();
}

class _NetworkInstancePageState extends State<NetworkInstancePage>
    with SingleTickerProviderStateMixin {
  late final _controller =
      widget.controller ?? NetworkInstanceController(id: widget.id);
  late final AppLifecycleListener _lifecycle;
  late final _tabs = TabController(
    length: InstanceTab.values.length,
    initialIndex: (widget.tab?.peek() ?? widget.initialTab).index,
    vsync: this,
  );
  void Function()? _unsubscribeTab;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) =>
          _controller.setActive(state == AppLifecycleState.resumed),
    );
    _controller.setActive(true);
    if (widget.tab case final tab?) {
      _unsubscribeTab = tab.subscribe((tab) => _tabs.animateTo(tab.index));
      _tabs.addListener(() => tab.value = InstanceTab.values[_tabs.index]);
    }
  }

  @override
  void dispose() {
    _unsubscribeTab?.call();
    _tabs.dispose();
    _lifecycle.dispose();
    _controller.setActive(false);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final network = _controller.network.value;
      if (network == null) {
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.networkTitle)),
          body: EmptyState(
            icon: Icons.error_outline,
            title: context.l10n.networkMissing,
            message: context.l10n.networkMissingDescription,
            action: FilledButton(
              onPressed: () => context.go('/networks'),
              child: Text(context.l10n.commonGoBack),
            ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(network.networkName),
          bottom: TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: context.l10n.networkPeers),
              Tab(text: context.l10n.networkLogs),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            InstancePeersTab(controller: _controller),
            InstanceLogsTab(controller: _controller),
          ],
        ),
      );
    },
  );
}
