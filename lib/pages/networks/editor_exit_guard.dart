import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// Mounted network editors with the key of the page each is shown on, and a
/// check for input that failed validation and therefore was never saved.
final _editors = <Object, (LocalKey?, bool Function())>{};

LocalKey? pageKeyOf(BuildContext context) =>
    switch (ModalRoute.of(context)?.settings) {
      Page(:final key) => key,
      _ => null,
    };

void registerEditor(
  Object editor,
  LocalKey? pageKey,
  bool Function() hasInvalidInput,
) => _editors[editor] = (pageKey, hasInvalidInput);

void unregisterEditor(Object editor) => _editors.remove(editor);

/// Whether to leave the page [pageKey]. Asks first when an editor on it shows
/// invalid input, since leaving discards it.
Future<bool> confirmLeavingPage(BuildContext context, LocalKey? pageKey) async {
  final invalid = _editors.values.any((e) => e.$1 == pageKey && e.$2());
  if (!invalid) return true;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: Text(context.l10n.networkDiscardTitle),
          content: Text(context.l10n.networkDiscardDescription),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.networkKeepEditing),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.networkDiscard),
            ),
          ],
        ),
      ) ??
      false;
}
