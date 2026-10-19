import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../controllers/network_editor_controller.dart';
import '../../l10n/l10n.dart';
import '../../widgets/empty_state/missing_network_state.dart';
import '../../widgets/snackbar/app_snackbar.dart';
import 'editor_exit_guard.dart';
import 'editor_pop_guard.dart';
import 'widgets/advanced_tab.dart';
import 'widgets/editor_basic_tab.dart';

/// The network editor: the Basic and Advanced tabs of one saved network.
///
/// It saves on every accepted keystroke; only invalid input asks before
/// leaving, through the guard registered for this page.
class NetworkEditorPage extends StatefulWidget {
  const NetworkEditorPage({
    super.key,
    required this.id,
    this.controller,
    this.guardKey,
  });

  /// Key of the network in the saved network collection.
  final String id;

  final NetworkEditorController? controller;

  /// The key this page registers its exit guard under. Defaults to the route's
  /// own key; the list page passes its detail pane's key.
  final Key? guardKey;

  @override
  State<NetworkEditorPage> createState() => _NetworkEditorPageState();
}

class _NetworkEditorPageState extends State<NetworkEditorPage>
    with SingleTickerProviderStateMixin {
  late final NetworkEditorController _controller =
      widget.controller ??
      NetworkEditorController(
        id: widget.id,
        showMessage: (message) => showAppSnackBar(context, message),
      );
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _basicForm = GlobalKey<FormState>();
  final _advancedForm = GlobalKey<FormState>();
  late final Key _guardKey = widget.guardKey ?? editorGuardKey(widget.id);

  /// Whether each tab's form is valid, as of the latest re-reading. A tab
  /// nobody opened counts as valid, exactly like [hasInvalidInput].
  final Signal<bool> _basicValid = signal(true);
  final Signal<bool> _advancedValid = signal(true);

  /// The stop function of the effect that re-reads both forms whenever the
  /// working copy changes.
  void Function()? _stopValidityEffect;

  /// Whether a re-reading is already scheduled for the end of this frame.
  bool _revalidateScheduled = false;

  /// Both tabs count, and a tab nobody opened has no invalid input to find.
  bool get hasInvalidInput {
    final basic = _basicForm.currentState?.validate() ?? true;
    final advanced = _advancedForm.currentState?.validate() ?? true;
    return !(basic && advanced);
  }

  /// Re-reads both forms, deferred to the end of the frame.
  ///
  /// The forms' own validity is the one source the guard and the pop guard
  /// share. It is re-read after a change in either form *and* after a change of
  /// the working copy, because a flag can enable a field that already holds
  /// invalid text without any field value changing. The re-reading is deferred
  /// so `Form.validate()` never runs inside a build, which a controller write
  /// made during one (the working copy's first value, or a field syncing its
  /// controller after a frame) would otherwise cause.
  void _revalidate() {
    if (_revalidateScheduled) return;
    _revalidateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revalidateScheduled = false;
      if (!mounted) return;
      _basicValid.value = _basicForm.currentState?.validate() ?? true;
      _advancedValid.value = _advancedForm.currentState?.validate() ?? true;
    });
  }

  @override
  void initState() {
    super.initState();
    registerExitGuard(_guardKey, () => hasInvalidInput);
    _stopValidityEffect = effect(() {
      // A flag, a generated key or any other model change can flip a form's
      // validity without touching a field's value.
      _controller.working.value;
      _revalidate();
    });
  }

  @override
  void dispose() {
    unregisterExitGuard(_guardKey);
    _tabs.dispose();
    _stopValidityEffect?.call();
    _basicValid.dispose();
    _advancedValid.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_controller.working.value == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.networkMissing)),
        body: MissingNetworkState(onGoBack: () => Navigator.of(context).pop()),
      );
    }
    final page = Scaffold(
      appBar: AppBar(
        title: SignalBuilder(
          builder: (context) => Text(l10n.networkEditNamed(_controller.name.value)),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.networkBasic),
            Tab(text: l10n.networkAdvanced),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _KeepAlive(
            child: EditorBasicTab(
              controller: _controller,
              formKey: _basicForm,
              onChanged: _revalidate,
            ),
          ),
          _KeepAlive(
            child: EditorAdvancedTab(
              controller: _controller,
              formKey: _advancedForm,
              onChanged: _revalidate,
            ),
          ),
        ],
      ),
    );
    // Only the page that owns the route guards its pop; the list's pane passes
    // its own guard key and must leave its host route alone.
    if (widget.guardKey != null) return page;
    return EditorPopGuard(
      basicValid: _basicValid,
      advancedValid: _advancedValid,
      guardKey: _guardKey,
      child: page,
    );
  }
}

/// Keeps a tab's fields, their text and their errors alive across switches.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
