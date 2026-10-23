import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/share/share_bundle.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_routes.dart';

void main() {
  test('one id writes a plain single-id location', () {
    expect(shareSendPaths(ShareKind.network, ['n1']), '/share/send/network/n1');
    expect(
      shareSendPaths(ShareKind.network, ['n1']),
      shareSendPath(ShareKind.network, 'n1'),
    );
    expect(shareSendIds('n1'), ['n1']);
  });

  test('several ids travel as one path component and come back in order', () {
    const ids = ['n1', 'relay.example.com:11010', 'b2'];

    final segment = shareSendPaths(ShareKind.node, ids).split('/').last;

    expect(
      segment.contains(','),
      isFalse,
      reason: 'the comma is percent-encoded, so go_router decodes one string',
    );
    expect(shareSendIds(Uri.decodeComponent(segment)), ids);
  });

  test('a link carries the first ids a bundle allows', () {
    final ids = [
      for (var index = 0; index <= shareMaxBundleItems; index++) 'n$index',
    ];

    expect(shareSendIds(ids.join(',')), hasLength(shareMaxBundleItems));
    expect(shareSendIds(''), isEmpty);
    expect(shareSendIds(null), isEmpty);
    expect(shareSendIds('n1,,n2'), ['n1', 'n2']);
  });
}
