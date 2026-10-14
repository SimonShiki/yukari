import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/l10n.dart';
import '../../../models/bookmark.dart';
import '../../../widgets/node_form/node_form_fields.dart';

/// Creates a bookmark, or edits the one passed as [initial].
class BookmarkEditorDialog extends StatefulWidget {
  const BookmarkEditorDialog({super.key, required this.onSave, this.initial});

  final Bookmark? initial;
  final ValueChanged<Bookmark> onSave;

  @override
  State<BookmarkEditorDialog> createState() => _BookmarkEditorDialogState();
}

class _BookmarkEditorDialogState extends State<BookmarkEditorDialog> {
  final _nodeKey = GlobalKey<NodeFormFieldsState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final TextEditingController _category = TextEditingController(
    text: widget.initial?.category ?? '',
  );
  late final TextEditingController _tags = TextEditingController(
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

  String? _optional(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  List<String> get _parsedTags => [
    for (final tag in _tags.text.split(','))
      if (tag.trim().isNotEmpty) tag.trim(),
  ];

  void _handleSave() {
    final node = _nodeKey.currentState?.validate();
    if (node == null) return;

    final initial = widget.initial;
    final tags = _parsedTags;
    widget.onSave(
      Bookmark(
        id: initial?.id ?? const Uuid().v4(),
        node: node,
        name: _optional(_name),
        description: _optional(_description),
        category: _optional(_category),
        tags: tags,
        // Fields another tool wrote are kept when its entry is edited.
        extensions: initial?.extensions ?? const {},
        createdAt: initial?.createdAt,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(
        editing ? context.l10n.bookmarksEdit : context.l10n.bookmarksAdd,
      ),
      content: SingleChildScrollView(
        // Room for the first field's floating label, which the scroll view
        // clips when it starts flush with the content edge.
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          // Narrow on phones, and never a wall of text on a wide window.
          width: math.min(MediaQuery.sizeOf(context).width * 0.8, 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: context.l10n.bookmarksName,
                  helperText: context.l10n.bookmarksNameHelper,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: context.l10n.bookmarksDescription,
                  helperText: context.l10n.bookmarksDescriptionHelper,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _category,
                decoration: InputDecoration(
                  labelText: context.l10n.bookmarksCategory,
                  helperText: context.l10n.bookmarksCategoryHelper,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tags,
                decoration: InputDecoration(
                  labelText: context.l10n.bookmarksTags,
                  helperText: context.l10n.bookmarksTagsHelper,
                  border: const OutlineInputBorder(),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(),
              ),
              NodeFormFields(key: _nodeKey, initialNode: widget.initial?.node),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _handleSave,
          child: Text(context.l10n.commonSave),
        ),
      ],
    );
  }
}
