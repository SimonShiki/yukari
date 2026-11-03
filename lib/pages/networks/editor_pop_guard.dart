import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'editor_exit_guard.dart';

/// Guards the pop of a route that owns an editor.
///
/// The route joins a predictive back gesture only while leaving loses nothing:
/// Android's guidance is not to join a gesture the pop can then veto. When it
/// does hold invalid input, back asks through the editor's exit guard instead,
/// and only a discarded answer pops the route.
class EditorPopGuard extends StatelessWidget {
  const EditorPopGuard({
    super.key,
    required this.basicValid,
    required this.advancedValid,
    required this.guardKey,
    required this.child,
  });

  /// Whether each tab's form is valid, as of its latest re-reading.
  final Signal<bool> basicValid;
  final Signal<bool> advancedValid;

  /// The key the editor registered its exit guard under.
  final Key guardKey;

  final Widget child;

  bool get _canLeave => basicValid.value && advancedValid.value;

  /// Asks about an editor that holds invalid input, then leaves it.
  Future<void> _leave(BuildContext context) async {
    if (!await confirmLeavingPage(context, guardKey)) return;
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    // The editor page is built once by its parent, so only this scope rebuilds
    // as the editor's validity changes.
    builder: (context) => PopScope(
      canPop: _canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _leave(context);
      },
      child: child,
    ),
  );
}
