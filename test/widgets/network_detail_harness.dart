import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/widgets/network_card/detail_container.dart';
import 'package:yukari/widgets/network_card/network_detail_transition.dart';

/// Sends one Android predictive back gesture event to the framework, the way
/// the platform does.
Future<void> backGesture(
  WidgetTester tester,
  String method, [
  double? progress,
]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall(method, <String, dynamic>{
        if (progress case final progress?) ...{
          'progress': progress,
          'touchOffset': <double>[5.0, 300.0],
          'swipeEdge': 0,
        },
      }),
    ),
    (_) {},
  );
  await tester.pump();
}

/// Frames the window as a phone would.
void useWindow(WidgetTester tester, {Size size = const Size(400, 800)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The visible bounds of the growing detail container.
Rect container(WidgetTester tester) =>
    tester.getRect(find.byKey(DetailContainer.containerKey));

/// The container's bounds, or null when no route is growing out of a card.
Rect? containerOrNull(WidgetTester tester) {
  final finder = find.byKey(DetailContainer.containerKey);
  return finder.evaluate().isEmpty ? null : tester.getRect(finder);
}

/// The transition the pushed detail route wears.
NetworkDetailTransition transitionOf(WidgetTester tester) =>
    tester.widget<NetworkDetailTransition>(
      find.byType(NetworkDetailTransition),
    );
