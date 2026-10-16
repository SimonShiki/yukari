import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../utils/line_formats.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_segments.dart';
export 'editor_controls.dart';

/// A labelled field segment that saves on every accepted keystroke.
///
/// The text is seeded from [initialValue] once; [value] only replaces it when
/// an edit elsewhere changes it (a generated key, a derived public key), so a
/// rebuild never interrupts typing.
class EditorTextField extends StatefulWidget {
  const EditorTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onSaved,
    this.value,
    this.hint,
    this.helper,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.copyTooltip,
    this.onCopy,
    this.textInputAction,
    this.onSubmitted,
    this.showTooltip,
    this.hideTooltip,
    this.generateTooltip,
    this.onGenerate,
  });

  final String label;
  final String initialValue;
  final void Function(String text) onSaved;
  final String? value;
  final String? hint;
  final String? helper;
  final String? Function(String value)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool enabled;

  /// Read-only fields stay selectable and copyable, with normal colors, unlike
  /// a disabled field, which greys out.
  final bool readOnly;

  /// Tooltip of the optional copy button, which calls [onCopy].
  final String? copyTooltip;
  final VoidCallback? onCopy;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  /// Show/hide tooltips; both make the field obfuscated.
  final String? showTooltip;
  final String? hideTooltip;

  /// Tooltip of the optional generate button.
  final String? generateTooltip;
  final VoidCallback? onGenerate;

  @override
  State<EditorTextField> createState() => _EditorTextFieldState();
}

class _EditorTextFieldState extends State<EditorTextField> {
  late final TextEditingController _text = TextEditingController(
    // An externally driven value is authoritative from the first build: the
    // seed a section read earlier can be stale by the time this field mounts.
    text: widget.value ?? widget.initialValue,
  );
  late bool _hidden = widget.showTooltip != null;

  @override
  void didUpdateWidget(covariant EditorTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (value == null || value == oldWidget.value) return;
    if (value == _text.text || value == _text.text.trim()) return;
    // Writing the controller notifies its Form, which must not happen while
    // the widget tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.value != value) return;
      _text.text = value;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _changed(String value) {
    if (widget.validator?.call(value) == null) widget.onSaved(value);
  }

  @override
  Widget build(BuildContext context) => FieldSegment(
    child: TextFormField(
      controller: _text,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: widget.showTooltip != null && _hidden,
      keyboardType: widget.keyboardType,
      maxLines: widget.showTooltip != null ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      // A field nobody can edit must not block the form: a programmatically
      // disabled field (an off VPN portal, a DHCP-managed address) keeps its
      // initial value, which its validator may not accept.
      validator: widget.validator == null || !widget.enabled
          ? null
          : (value) => widget.validator!(value ?? ''),
      onChanged: _changed,
      onFieldSubmitted:
          widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        suffixIcon: _suffix(context),
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget? _suffix(BuildContext context) {
    final buttons = <Widget>[
      if (widget.onCopy case final copy?)
        IconButton(
          tooltip: widget.copyTooltip,
          onPressed: copy,
          icon: const Icon(Icons.content_copy_rounded),
        ),
      if (widget.showTooltip case final show?)
        IconButton(
          tooltip: _hidden ? show : widget.hideTooltip,
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      if (widget.onGenerate case final generate?)
        IconButton(
          tooltip: widget.generateTooltip,
          onPressed: generate,
          icon: const Icon(Icons.auto_awesome_rounded),
        ),
    ];
    if (buttons.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }
}

/// A field of one entry per line, saved as its trimmed non-empty lines.
class EditorLinesField extends StatelessWidget {
  const EditorLinesField({
    super.key,
    required this.label,
    required this.helper,
    required this.hint,
    required this.initialValue,
    required this.validateLine,
    required this.onSaved,
  });

  final String label;
  final String helper;
  final String hint;
  final String initialValue;
  final String? Function(String line) validateLine;
  final void Function(List<String> lines) onSaved;

  @override
  Widget build(BuildContext context) => EditorTextField(
    label: label,
    hint: hint,
    helper: context.l10n.networkOnePerLine(helper),
    initialValue: initialValue,
    maxLines: 3,
    validator: (value) => validateLines(value, validateLine),
    onSaved: (value) => onSaved(splitLines(value)),
  );
}
