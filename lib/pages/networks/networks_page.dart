import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../../controllers/network_instance_controller.dart';
import '../../controllers/network_page_controller.dart';
import '../../l10n/l10n.dart';
import '../../widgets/network_card/network_card_list.dart';
import '../../widgets/network_card/network_card_data.dart';
import '../../widgets/empty_state/empty_state.dart';
import '../../widgets/snackbar/app_snackbar.dart';
import 'editor_exit_guard.dart';
import 'network_editor_page.dart';
import 'network_page_dialogs.dart';
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
          navigate: (route, id) {
            if (route.startsWith('/')) {
              context.go(route);
            } else {
              context.goNamed(route, pathParameters: {'id': id!});
            }
          },
          showMessage: (message) {
            if (!mounted) return;
            showAppSnackBar(context, message);
          },
          confirmDelete: (network) => confirmNetworkDeletion(context, network),
          showTunPermissionWarning: (network) =>
              showTunPermissionWarning(context, network),
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

  /// Runs [action], which replaces the embedded editor, once any invalid
  /// input shown there may be discarded.
  Future<void> _leaveEditor(VoidCallback action) async {
    if (await confirmLeavingPage(context, pageKeyOf(context)) && mounted) {
      action();
    }
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
          // Beside a detail pane the menu belongs to the list pane, but on its
          // own it is the page's FAB, so the Scaffold can nudge a floating
          // snackbar above it.
          final createMenu = NetworkCreateMenu(
            onCreate: _controller.createManually,
            onImport: _controller.importFromFile,
            onScan: _controller.scanQrCode,
          );

          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.navNetworks),
              actions: [
                IconButton(
                  tooltip: context.l10n.networkRefresh,
                  onPressed: _controller.refreshing.value
                      ? null
                      : _controller.refresh,
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
                                    child: Text(context.l10n.commonRetry),
                                  ),
                                ],
                              ),
                            Expanded(
                              child: cards.isEmpty
                                  ? EmptyState(
                                      icon: Icons.hub_outlined,
                                      title: context.l10n.networkEmpty,
                                      message:
                                          context.l10n.networkEmptyDescription,
                                    )
                                  : Align(
                                      alignment: Alignment.topCenter,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: isLargeScreen ? 500 : 1000,
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final selectedIndex =
                                                selectedNetwork != null
                                                ? cards.indexWhere(
                                                    (card) =>
                                                        card.id ==
                                                        selectedNetwork,
                                                  )
                                                : null;
                                            return NetworkCardList(
                                              networks: cards.map((card) {
                                                return NetworkCardData(
                                                  id: card.id,
                                                  name: card.name,
                                                  status: card.status,
                                                  running: card.running,
                                                  busy: card.busy,
                                                  onOpen: isLargeScreen
                                                      ? () {
                                                          if (card.id !=
                                                              selectedNetwork) {
                                                            _leaveEditor(
                                                              card.onOpen,
                                                            );
                                                          }
                                                        }
                                                      : () {
                                                          if (card.running) {
                                                            context.go(
                                                              '/networks/instance/${card.id}',
                                                            );
                                                          } else {
                                                            context.go(
                                                              '/networks/edit/${card.id}',
                                                            );
                                                          }
                                                        },
                                                  onEdit: card.onEdit,
                                                  onLog: isLargeScreen
                                                      ? () => _leaveEditor(
                                                          () => _controller
                                                              .selectNetwork(
                                                                card.id,
                                                                tab: InstanceTab
                                                                    .logs,
                                                              ),
                                                        )
                                                      : card.onLog,
                                                  onDelete: card.onDelete,
                                                  onToggle:
                                                      isLargeScreen &&
                                                          card.id ==
                                                              selectedNetwork &&
                                                          card.onToggle != null
                                                      ? (value) => _leaveEditor(
                                                          () => card.onToggle!(
                                                            value,
                                                          ),
                                                        )
                                                      : card.onToggle,
                                                );
                                              }).toList(),
                                              onReorder: _controller.reorder,
                                              keyBuilder:
                                                  _controller.keyForIndex,
                                              showDragHandles: false,
                                              selectedIndex:
                                                  isLargeScreen &&
                                                      selectedIndex != null &&
                                                      selectedIndex != -1
                                                  ? selectedIndex
                                                  : null,
                                              onSelectionChanged: (index) {
                                                if (index != null) {
                                                  final card = cards[index];
                                                  if (isLargeScreen) {
                                                    if (card.id !=
                                                        selectedNetwork) {
                                                      _leaveEditor(card.onOpen);
                                                    }
                                                  } else if (card.running) {
                                                    context.go(
                                                      '/networks/instance/${card.id}',
                                                    );
                                                  } else {
                                                    context.go(
                                                      '/networks/edit/${card.id}',
                                                    );
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
                        if (isLargeScreen)
                          Positioned(right: 16, bottom: 16, child: createMenu),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                              width: 1,
                            ),
                          ),
                        ),
                        child: selectedNetworkRunning
                            ? NetworkInstancePage(
                                key: ValueKey(selectedNetwork),
                                id: selectedNetwork,
                                tab: _controller.selectedTab,
                              )
                            : NetworkEditorPage(
                                key: ValueKey(selectedNetwork),
                                name: selectedNetwork,
                              ),
                      ),
                    ),
                ],
              ),
            ),
            floatingActionButton: isLargeScreen ? null : createMenu,
          );
        },
      );
    },
  );
}
