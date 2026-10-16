import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/network_instance_controller.dart';
import '../../l10n/l10n.dart';
import '../../widgets/empty_state/empty_state.dart';
import 'widgets/instance_tabs.dart';

export '../../controllers/network_instance_controller.dart' show InstanceTab;

/// One network's instance: its peers, and its logs.
class NetworkInstancePage extends StatefulWidget {
  const NetworkInstancePage({
    super.key,
    required this.id,
    this.initialTab = InstanceTab.peers,
    this.tab,
    this.controller,
  });

  /// Key of the network in the saved network collection.
  final String id;

  /// The tab the route asks for.
  final InstanceTab initialTab;

  /// A signal the list page keeps its detail pane's tab in, kept in sync both
  /// ways by the controller this page creates.
  final Signal<InstanceTab>? tab;

  final NetworkInstanceController? controller;

  @override
  State<NetworkInstancePage> createState() => _NetworkInstancePageState();
}

class _NetworkInstancePageState extends State<NetworkInstancePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final NetworkInstanceController _controller =
      widget.controller ??
      NetworkInstanceController(
        id: widget.id,
        initialTab: widget.initialTab,
        tab: widget.tab,
      );
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: _controller.selectedTab.value.index,
  );
  late final void Function() _stopTabEffect;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs.addListener(_pushTab);
    // Controller -> widget: the controller owns the selected tab, and the
    // listener below reports the user's own switches back to it.
    _stopTabEffect = effect(() {
      final tab = _controller.selectedTab.value;
      if (_tabs.index != tab.index) _tabs.index = tab.index;
    });
  }

  void _pushTab() => _controller.selectTab(InstanceTab.values[_tabs.index]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncActive();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncActive();
  }

  /// The 2s refresh only runs while the page is in the foreground.
  void _syncActive() => _controller.setActive(
    _foreground && (ModalRoute.isCurrentOf(context) ?? false),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.setActive(false);
    _stopTabEffect();
    _tabs.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final missing = _controller.missing.value;
    return Scaffold(
      appBar: AppBar(
        title: SignalBuilder(
          builder: (context) => Text(
            missing ? l10n.networkMissing : _controller.name.value,
          ),
        ),
        bottom: missing
            ? null
            : TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: l10n.networkPeers),
                  Tab(text: l10n.networkLogs),
                ],
              ),
      ),
      body: missing
          ? EmptyState(
              icon: Icons.error_outline,
              title: l10n.networkMissing,
              message: l10n.networkMissingDescription,
              action: FilledButton(
                onPressed: () => context.go('/networks'),
                child: Text(l10n.commonGoBack),
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                InstancePeersTab(controller: _controller),
                InstanceLogsTab(controller: _controller),
              ],
            ),
    );
  }

}
