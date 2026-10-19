import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../widgets/form_section/section_list.dart';
import 'editor_identity_section.dart';
import 'editor_ip_section.dart';
import 'editor_peers_section.dart';
import 'editor_startup_section.dart';

/// The Basic tab: identity, IP configuration, startup and the initial peers.
class EditorBasicTab extends StatelessWidget {
  const EditorBasicTab({
    super.key,
    required this.controller,
    required this.formKey,
    this.onChanged,
  });

  final NetworkEditorController controller;
  final GlobalKey<FormState> formKey;

  /// Called when a field of this tab's form changes, so the page can keep its
  /// knowledge of whether this tab holds invalid input current.
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    onChanged: onChanged,
    child: SectionList(
      children: [
        EditorIdentitySection(controller: controller),
        EditorIpSection(controller: controller),
        // Only this section depends on a signal: it appears when the backend
        // can start networks with the system.
        SignalBuilder(
          builder: (context) =>
              EditorStartupSection.supported(controller.backendKind.value)
              ? EditorStartupSection(controller: controller)
              : const SizedBox.shrink(),
        ),
        EditorPeersSection(controller: controller),
      ],
    ),
  );
}
