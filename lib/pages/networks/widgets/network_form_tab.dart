import 'package:material_ui/material_ui.dart';

import '../../../widgets/form_section/section_list.dart';

/// The validated form holding the sections of one editor tab.
class NetworkFormTab extends StatelessWidget {
  const NetworkFormTab({
    super.key,
    required this.formKey,
    required this.children,
  });

  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    child: SectionList(children: children),
  );
}
