import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// Keys the exit guards are registered under.
///
/// `go_router` names a route's page after its matched location, which is what
/// `state.pageKey` carries in the frozen `lib/router.dart`; these mirror those
/// locations so a page can register its own guard while it is mounted.
const ValueKey<String> networksGuardKey = ValueKey<String>('/networks');

/// Key of the `/networks/edit/:id` route's page.
ValueKey<String> editorGuardKey(String id) =>
    ValueKey<String>('/networks/edit/$id');

/// Key of the editor the list page shows in its detail pane, which is a second
/// editor for the same network and so needs its own registration.
ValueKey<String> paneGuardKey(String id) =>
    ValueKey<String>('/networks#edit/$id');

final _guards = <Key, bool Function()>{};

/// Registers the invalid-input check of the page (or pane) named [key].
void registerExitGuard(Key key, bool Function() hasInvalidInput) =>
    _guards[key] = hasInvalidInput;

/// Forgets the check registered for [key].
void unregisterExitGuard(Key key) => _guards.remove(key);

/// Whether the page named [key] currently holds invalid input.
bool hasInvalidInput(Key key) => _guards[key]?.call() ?? false;

/// `go_router`'s exit guard: leaves silently, or asks before invalid input is
/// discarded.
Future<bool> confirmLeavingPage(BuildContext context, Key pageKey) async {
  if (!hasInvalidInput(pageKey)) return true;
  // Discarding allows the page to leave; keeping the edits does not.
  return confirmDiscardChanges(context);
}

/// Asks whether invalid input may be discarded; true when the user discards,
/// false when it is kept (including a dismissed dialog).
Future<bool> confirmDiscardChanges(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(context.l10n.networkDiscardTitle),
        content: Text(context.l10n.networkDiscardDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.networkKeepEditing),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.networkDiscard),
          ),
        ],
      ),
    ) ??
    false;
