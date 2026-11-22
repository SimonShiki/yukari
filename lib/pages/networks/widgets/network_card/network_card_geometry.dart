import 'package:material_ui/material_ui.dart';

import '../../../../models/network_card_data.dart';

/// The origin available to the route while a card opens it.
final networkCardOrigin = NetworkCardOrigin();

class NetworkCardOrigin {
  Rect? value;
}

Rect? takeNetworkCardOrigin() {
  final origin = networkCardOrigin.value;
  networkCardOrigin.value = null;
  return origin;
}

/// Keeps card keys distinct from other GlobalObjectKeys for the same data.
class NetworkCardKey extends GlobalObjectKey<State<StatefulWidget>> {
  const NetworkCardKey(NetworkCardData super.value);
}

/// Measures the card when navigation begins, after any scroll or layout change.
void withNetworkCardOrigin(NetworkCardData card, VoidCallback open) {
  final context = NetworkCardKey(card).currentContext;
  final box = context?.findRenderObject();
  if (context != null && box is RenderBox && box.hasSize) {
    final navigator = Navigator.of(context);
    final origin = box.localToGlobal(
      Offset.zero,
      ancestor: navigator.context.findRenderObject(),
    );
    networkCardOrigin.value = origin & box.size;
  }
  try {
    open();
  } finally {
    networkCardOrigin.value = null;
  }
}
