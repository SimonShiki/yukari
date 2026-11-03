import 'package:material_ui/material_ui.dart';

/// The app's one card container: a container-toned surface with the 20 dp
/// corner every card shares, and an ink surface for cards that open something.
///
/// The fill and the corner live here and nowhere else, so a home tile and a
/// share card cannot drift apart; each caller owns its own padding.
class CardSurface extends StatelessWidget {
  const CardSurface({super.key, required this.child, this.onTap});

  /// The card's content, already padded by the caller.
  final Widget child;

  /// What a tap on the card opens; only cards with an action pass one, and the
  /// rest stay a plain surface with no ink.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
    );
  }
}
