import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures `Clipboard.setData` calls on [SystemChannels.platform] for the
/// duration of the test and returns the copied strings in order.
List<String> mockClipboard() {
  final copied = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      final text = (call.arguments as Map<Object?, Object?>?)?['text'];
      if (text is String) copied.add(text);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return copied;
}
