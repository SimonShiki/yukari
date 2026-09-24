import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../../controllers/network_page_controller.dart';
import '../../widgets/network_card/network_card_list.dart';
import '../../widgets/network_card/network_card_data.dart';
import 'network_editor_page.dart';
import 'network_page_dialogs.dart';
import 'network_page_empty_state.dart';
import 'network_create_menu.dart';
import 'network_instance_page.dart';

class NetworksPage extends StatefulWidget {
  const NetworksPage({super.key, this.controller});

  final NetworkPageController? controller;

  @override
  State<NetworksPage> createState() => _NetworksPageState();
}

class _NetworksPageState extends State<NetworksPage>
    with WidgetsBindingObserver {
  late final NetworkPageController _controller;
  bool _routeVisible = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _controller =
        widget.controller ??
        NetworkPageController(
          navigate: (route, name) {
            if (route.startsWith('/')) {
              context.go(route);
            } else {
              context.goNamed(route, pathParameters: {'name': name!});
            }
          },
          showMessage: (message) {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(message)));
          },
          confirmDelete: (network) => confirmNetworkDeletion(context, network),
          showLog: (instance) => showNetworkLog(context, instance),
          showTunPermissionWarning: (network) => showTunPermissionWarning(context, network),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeVisible = ModalRoute.isCurrentOf(context) ?? true;
    _controller.setActive(_routeVisible && _foreground);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _controller.setActive(_routeVisible && _foreground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.setActive(false);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final cards = _controller.cards.value;
      final selectedNetwork = _controller.selectedNetwork.value;
      final selectedNetworkRunning = _controller.selectedNetworkRunning.value;

      return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 840;
        final showDetail = isLargeScreen && selectedNetwork != null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Networks'),
            actions: [
              IconButton(
                tooltip: 'Refresh network status',
                onPressed: _controller.refreshing.value ? null : _controller.refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          if (_controller.error.value case final error?)
                            MaterialBanner(
                              content: Text(error),
                              leading: const Icon(Icons.cloud_off_outlined),
                              actions: [
                                TextButton(
                                  onPressed: _controller.refreshing.value
                                      ? null
                                      : _controller.refresh,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          Expanded(
                            child: cards.isEmpty
                                ? const NetworkPageEmptyState()
                                : Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: isLargeScreen ? 500 : 1000,
                                      ),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final selectedIndex = selectedNetwork != null
                                              ? cards.indexWhere((card) => card.name == selectedNetwork)
                                              : null;
                                          return NetworkCardList(
                                            networks: cards.map((card) {
                                              return NetworkCardData(
                                                name: card.name,
                                                status: card.status,
                                                running: card.running,
                                                busy: card.busy,
                                                onOpen: isLargeScreen
                                                    ? card.onOpen
                                                    : () => context.go('/networks/edit/${card.name}'),
                                                onEdit: card.onEdit,
                                                onLog: card.onLog,
                                                onDelete: card.onDelete,
                                                onToggle: card.onToggle,
                                              );
                                            }).toList(),
                                            onReorder: _controller.reorder,
                                            keyBuilder: _controller.keyForIndex,
                                            showDragHandles: false,
                                            selectedIndex: isLargeScreen && selectedIndex != null && selectedIndex != -1 ? selectedIndex : null,
                                            onSelectionChanged: (index) {
                                              if (index != null) {
                                                if (isLargeScreen) {
                                                  cards[index].onOpen();
                                                } else {
                                                  context.go('/networks/edit/${cards[index].name}');
                                                }
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: NetworkCreateMenu(
                          onCreate: _controller.createManually,
                          onImport: _controller.importFromFile,
                          onScan: _controller.scanQrCode,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showDetail)
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                      ),
                      child: selectedNetworkRunning
                          ? NetworkInstancePage(name: selectedNetwork)
                          : NetworkEditorPage(name: selectedNetwork),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  });
}
