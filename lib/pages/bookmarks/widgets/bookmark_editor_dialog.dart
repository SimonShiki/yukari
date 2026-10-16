import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../controllers/bookmarks_actions.dart';
import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';
import '../../../widgets/node_form/node_form_fields.dart';

/// Asks for one bookmark's fields and returns them, or null when dismissed.
Future<BookmarkDraft?> showBookmarkEditorDialog(
  BuildContext context, {
  Bookmark? initial,
}) => showDialog<BookmarkDraft>(
  context: context,
  builder: (context) => _BookmarkEditorDialog(initial: initial),
);

class _BookmarkEditorDialog extends StatefulWidget {
  const _BookmarkEditorDialog({this.initial});

  final Bookmark? initial;

  @override
  State<_BookmarkEditorDialog> createState() => _BookmarkEditorDialogState();
}

class _BookmarkEditorDialogState extends State<_BookmarkEditorDialog> {
  final _nodeKey = GlobalKey<NodeFormFieldsState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _category = TextEditingController(
    text: widget.initial?.category ?? '',
  );
  late final _tags = TextEditingController(
    text: widget.initial?.tags.join(', ') ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _category.dispose();
    _tags.dispose();
    super.dispose();
  }

  /// Closes with the draft only when the node fields validate.
  void _save() {
    final node = _nodeKey.currentState?.validate();
    if (node == null) return;
    Navigator.of(context).pop((
      node: node,
      name: _name.text,
      description: _description.text,
      category: _category.text,
      tags: _tags.text,
    ));
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String helper,
  ) => TextField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      border: const OutlineInputBorder(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.initial == null ? l10n.bookmarksAdd : l10n.bookmarksEdit,
      ),
      content: SizedBox(
        // Narrow on phones, and never a wall of fields on a wide window.
        width: math.min(MediaQuery.sizeOf(context).width * 0.8, 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              _field(_name, l10n.bookmarksName, l10n.bookmarksNameHelper),
              _field(
                _description,
                l10n.bookmarksDescription,
                l10n.bookmarksDescriptionHelper,
              ),
              _field(
                _category,
                l10n.bookmarksCategory,
                l10n.bookmarksCategoryHelper,
              ),
              _field(_tags, l10n.bookmarksTags, l10n.bookmarksTagsHelper),
              NodeFormFields(key: _nodeKey, initialNode: widget.initial?.node),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}
