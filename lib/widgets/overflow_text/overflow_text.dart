import 'package:material_ui/material_ui.dart';

/// Text that keeps its line limit but can still be read in full.
///
/// When the text does not fit, the user reveals the whole string by hovering
/// with a mouse or long-pressing on touch; when it fits, this is a plain
/// [Text] — no tooltip, no changed semantics.
///
/// Used for titles and messages that a phone truncates: log summaries, peer
/// hostnames, bookmark names, network names.
class OverflowText extends StatelessWidget {
  const OverflowText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
      final painter = TextPainter(
        text: TextSpan(text: text, style: effectiveStyle),
        maxLines: maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);

      final child = Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      );
      if (!painter.didExceedMaxLines) return child;
      // The default tooltip trigger is already hover on a mouse and long-press
      // on touch; only the reveal of a truncated line is added.
      return Tooltip(message: text, child: child);
    },
  );
}
