import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/network.dart';
import '../../../models/network_flags.dart';
import '../../../utils/line_formats.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_segments.dart';
import 'validated_text_field.dart';

/// A switch segment bound to one boolean of the edited network.
class NetworkSwitch extends StatelessWidget {
  const NetworkSwitch({
    super.key,
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.read,
    required this.write,
  });

  final NetworkEditorController controller;
  final String title;
  final String subtitle;
  final bool Function(Network network) read;
  final void Function(Network network, bool value) write;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => SwitchSegment(
      title: title,
      subtitle: subtitle,
      value: read(controller.network.value!),
      onChanged: (v) => controller.update((n) => write(n, v)),
    ),
  );
}

/// A [NetworkSwitch] bound to one of the network's flags.
class FlagSwitch extends StatelessWidget {
  const FlagSwitch({
    super.key,
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.read,
    required this.write,
  });

  final NetworkEditorController controller;
  final String title;
  final String subtitle;
  final bool Function(NetworkFlags flags) read;
  final void Function(NetworkFlags flags, bool value) write;

  @override
  Widget build(BuildContext context) => NetworkSwitch(
    controller: controller,
    title: title,
    subtitle: subtitle,
    read: (n) => read(n.flags),
    write: (n, v) => write(n.flags, v),
  );
}

/// A dropdown segment choosing one of [options] for the edited network.
class NetworkChoice<T> extends StatelessWidget {
  const NetworkChoice({
    super.key,
    required this.controller,
    required this.label,
    required this.options,
    required this.read,
    required this.write,
    this.helper,
  });

  final NetworkEditorController controller;
  final String label;
  final String? helper;

  /// Labels of the choices, in display order.
  final Map<T, String> options;
  final T Function(Network network) read;
  final void Function(Network network, T value) write;

  @override
  Widget build(BuildContext context) => FieldSegment(
    child: DropdownMenu<T>(
      expandedInsets: EdgeInsets.zero,
      label: Text(label),
      helperText: helper,
      initialSelection: read(controller.network.peek()!),
      dropdownMenuEntries: [
        for (final MapEntry(:key, :value) in options.entries)
          DropdownMenuEntry(value: key, label: value),
      ],
      onSelected: (v) {
        if (v != null) controller.update((n) => write(n, v));
      },
    ),
  );
}

/// A text segment editing a list of strings, one per line.
class LineListField extends StatelessWidget {
  const LineListField({
    super.key,
    required this.label,
    required this.helper,
    required this.initial,
    required this.validateLine,
    required this.onValid,
    this.hint,
  });

  final String label;
  final String helper;
  final String? hint;
  final Iterable<String> initial;
  final String? Function(String line) validateLine;
  final ValueChanged<List<String>> onValid;

  @override
  Widget build(BuildContext context) => FieldSegment(
    child: ValidatedTextField(
      initialValue: initial.join('\n'),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: context.l10n.networkOnePerLine(helper),
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      maxLines: 3,
      validator: (v) => validateLines(v, validateLine),
      onValid: (v) => onValid(splitLines(v)),
    ),
  );
}

/// A text segment for an optional whole number; empty means unset.
class OptionalIntField extends StatelessWidget {
  const OptionalIntField({
    super.key,
    required this.label,
    required this.helper,
    required this.initial,
    required this.min,
    required this.max,
    required this.onValid,
  });

  final String label;
  final String helper;
  final int? initial;
  final int min;
  final int max;
  final ValueChanged<int?> onValid;

  @override
  Widget build(BuildContext context) => FieldSegment(
    child: ValidatedTextField(
      initialValue: initial?.toString(),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (v) => validateOptionalIntRange(v, label, min, max),
      onValid: (v) => onValid(int.tryParse(v.trim())),
    ),
  );
}
