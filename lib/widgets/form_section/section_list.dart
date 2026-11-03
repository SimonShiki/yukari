import 'package:material_ui/material_ui.dart';

import 'form_section.dart';

/// Scrollable page of [FormSection]s: compact window margins, a readable
/// maximum width, and even gaps between sections.
class SectionList extends StatelessWidget {
  const SectionList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 32,
          children: children,
        ),
      ),
    ),
  );
}
