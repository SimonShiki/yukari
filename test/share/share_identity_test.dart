import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/pages/share/widgets/share_identity.dart';

import 'share_fixture.dart';

void main() {
  test('a network share is titled by its name and adds nothing', () {
    final document = sharedNetworkDocument();

    expect(shareDisplayTitle(document), 'alpha');
    expect(shareDisplaySubtitle(document), isNull);
  });

  test('a named node share is titled by its name and shows its address', () {
    final document = sharedNodeDocument(name: 'Relay One');

    expect(shareDisplayTitle(document), 'Relay One');
    expect(shareDisplaySubtitle(document), 'relay.example.com:11010');
  });

  test('an unnamed node share is titled by its address and adds nothing', () {
    final document = sharedNodeDocument();

    expect(shareDisplayTitle(document), 'relay.example.com:11010');
    expect(shareDisplaySubtitle(document), isNull);
  });
}
