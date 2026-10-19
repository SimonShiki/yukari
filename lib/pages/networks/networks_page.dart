import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/network_page_controller.dart';
import '../../l10n/l10n.dart';
import '../../widgets/network_card/network_card_data.dart';
import '../../widgets/network_card/network_card_geometry.dart';
import '../../widgets/snackbar/app_snackbar.dart';
import 'editor_exit_guard.dart';
import 'foreground_active.dart';
import 'network_create_menu.dart';
import 'network_editor_page.dart';
import 'network_instance_page.dart';
import 'network_page_dialogs.dart';
import 'widgets/networks_list_pane.dart';

/// The networks list, with the selected network beside it on wide windows.
class NetworksPage extends StatefulWidget {
  const NetworksPage({super.key, this.controller});

  final NetworkPageController? controller;

  @override
  State<NetworksPage> createState() => _NetworksPageState();
}

class _NetworksPageState extends State<NetworksPage>
    with WidgetsBindingObserver, ForegroundActive<NetworksPage> {
  late final NetworkPageController _controller =
      widget.controller ??
      NetworkPageController(
        navigate: _navigate,
        showMessage: (message) => showAppSnackBar(context, message),
        confirmDelete: (network) => confirmDeleteNetwork(context, network),
        showTunPermissionWarning: (network) => showTunPermissionWarningDialog(
          context,
          network,
          _controller.activeBackend,
          serviceSupported: _controller.serviceSupported,
        ),
        isWide: () => _wide,
        invalidInput: _paneInvalid,
        confirmDiscardDialog: () => confirmDiscardChanges(context),
      );

  /// The window class the last layout ran with, for the controller's actions.
  bool _wide = false;

  bool _paneInvalid() => hasInvalidInput(
    paneGuardKey(_controller.selectedId.value ?? ''),
  );

  @override
  void initState() {
    super.initState();
    startForegroundTracking();
    _controller.start();
    registerExitGuard(networksGuardKey, _paneInvalid);
  }

  /// The 10s refresh only runs while the list is visible in the foreground.
  @override
  void setActive(bool active) => _controller.setActive(active);

  @override
  void dispose() {
    stopForegroundTracking();
    unregisterExitGuard(networksGuardKey);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _navigate(String route, String? id) {
    if (id == null || route.startsWith('/')) {
      context.go(route);
    } else {
      context.goNamed(
        route,
        pathParameters: {'id': id},
        extra: takeNetworkCardOrigin(),
      );
    }
  }

  Future<void> _select(
    List<NetworkCardData> cards,
    int? index, {
    required bool wide,
  }) async {
    final id = index == null || index >= cards.length ? null : cards[index].id;
    // The wide pane always shows a network, so a deselect keeps the selection.
    if (id == null && wide) return;
    if (id != null && !await _controller.select(id)) return;
    if (!mounted || id == null || wide) return;
    // Narrow windows have no detail pane, so every tap opens the route once.
    _controller.openDetail(id);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= _wideBreakpoint;
      _wide = wide;
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.navNetworks),
          actions: [
            SignalBuilder(
              builder: (context) => IconButton(
                tooltip: context.l10n.networkRefresh,
                onPressed: _controller.refreshing.value
                    ? null
                    : _controller.refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ],
        ),
        floatingActionButton: wide
            ? null
            : NetworkCreateMenu(controller: _controller),
        body: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: NetworksListPane(
                  controller: _controller,
                  wide: wide,
                  onSelect: (cards, index) =>
                      _select(cards, index, wide: wide),
                ),
              ),
              if (wide)
                SignalBuilder(
                  builder: (context) {
                    final id = _controller.selectedId.value;
                    if (id == null) return const SizedBox.shrink();
                    return _detailPane(
                      id,
                      running: _controller.selectionRunning.value,
                    );
                  },
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _detailPane(String id, {required bool running}) => Expanded(
    flex: 2,
    child: Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: running
          ? NetworkInstancePage(
              key: ValueKey('instance-$id'),
              id: id,
              tab: _controller.instanceTab,
            )
          : NetworkEditorPage(
              key: ValueKey('editor-$id'),
              id: id,
              guardKey: paneGuardKey(id),
            ),
    ),
  );

  static const _wideBreakpoint = 840.0;
}
