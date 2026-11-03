import 'package:material_ui/material_ui.dart';

/// The frame every share page draws in: a column at most 600 points wide,
/// padded and scrollable, centred on a larger window.
class SharePageBody extends StatelessWidget {
  const SharePageBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;

  /// The space between the content and the window edge.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: SingleChildScrollView(padding: padding, child: child),
    ),
  );
}
