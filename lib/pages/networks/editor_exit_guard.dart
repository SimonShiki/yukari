import 'package:material_ui/material_ui.dart';

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
          title: const Text('Discard invalid changes?'),
          content: const Text(
            'Some fields contain invalid values that were not saved. '
            'Leaving will discard them.',
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;
}
