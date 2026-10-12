import 'package:material_ui/material_ui.dart';

/// A [TextFormField] that reports input through [onValid] only once
/// [validator] accepts it, so invalid values never reach the model.
/// Errors show in real time when an ancestor [Form] autovalidates.
class ValidatedTextField extends StatelessWidget {
  const ValidatedTextField({
    super.key,
    required this.decoration,
    required this.onValid,
    this.validator,
    this.controller,
    this.initialValue,
    this.enabled = true,
    this.obscureText = false,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
  });

  final InputDecoration decoration;
  final ValueChanged<String> onValid;
  final String? Function(String value)? validator;
  final TextEditingController? controller;
  final String? initialValue;
  final bool enabled;
  final bool obscureText;
  final int? maxLength;
  final int? maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    initialValue: initialValue,
    decoration: decoration,
    enabled: enabled,
    obscureText: obscureText,
    maxLength: maxLength,
    maxLines: maxLines,
    keyboardType: keyboardType,
    validator: validator == null ? null : (value) => validator!(value ?? ''),
    onChanged: (value) {
      if (validator?.call(value) == null) onValid(value);
    },
  );
}
