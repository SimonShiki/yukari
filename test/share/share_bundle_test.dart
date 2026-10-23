import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/share/share_bundle.dart';
import 'package:yukari/share/share_document.dart';

import 'share_fixture.dart';

void main() {
  /// The bundle envelope around [items], built by hand so a malformed one can
  /// be crafted.
  String bundleJson(List<Object?> items) => jsonEncode({
    'v': shareDocumentVersion,
    'kind': shareBundleKind,
    'items': items,
  });

  test('one item encodes exactly as the document does', () {
    for (final document in [sharedNetworkDocument(), sharedNodeDocument()]) {
      expect(encodeShareItems([document]), document.encode());
      expect(
        decodeShareItems(document.encode()).single.encode(),
        document.encode(),
      );
    }
  });

  test('several items round-trip in the order they were shared', () {
    final documents = [
      networkShare('alpha'),
      networkShare('beta'),
      networkShare('gamma'),
    ];

    final encoded = encodeShareItems(documents);
    final json = jsonDecode(encoded) as Map<String, Object?>;

    expect(json['v'], shareDocumentVersion);
    expect(json['kind'], shareBundleKind);
    expect(json['items'], hasLength(3));
    final decoded = decodeShareItems(encoded);
    expect(decoded.map((document) => document.name), [
      'alpha',
      'beta',
      'gamma',
    ]);
    expect(decoded.first.peers.single.address, 'relay.example.com:11010');
  });

  test('refuses to encode no items, too many, or a mix of kinds', () {
    final network = networkShare('alpha');
    final node = sharedNodeDocument();

    expect(() => encodeShareItems(const []), throwsArgumentError);
    expect(
      () => encodeShareItems([
        for (var index = 0; index <= shareMaxBundleItems; index++)
          networkShare('alpha-$index'),
      ]),
      throwsArgumentError,
    );
    expect(() => encodeShareItems([network, node]), throwsArgumentError);
  });

  test('refuses a bundle without items, an empty one and one over the cap', () {
    final item = networkShare('alpha').toJson();
    final noItems = Map.of(
      jsonDecode(bundleJson([item])) as Map<String, Object?>,
    )..remove('items');

    expect(
      () => decodeShareItems(jsonEncode(noItems)),
      throwsFormatException,
      reason: 'bundle without items',
    );
    expect(() => decodeShareItems(bundleJson([])), throwsFormatException);
    expect(
      () => decodeShareItems(
        bundleJson(List<Object?>.filled(shareMaxBundleItems + 1, item)),
      ),
      throwsFormatException,
      reason: 'more items than a bundle carries',
    );
  });

  test('refuses a bundle that mixes kinds or names another version', () {
    final network = networkShare('alpha').toJson();
    final node = sharedNodeDocument().toJson();
    final otherVersion = Map.of(
      jsonDecode(bundleJson([network])) as Map<String, Object?>,
    )..['v'] = shareDocumentVersion + 1;

    expect(
      () => decodeShareItems(bundleJson([network, node])),
      throwsFormatException,
    );
    expect(
      () => decodeShareItems(jsonEncode(otherVersion)),
      throwsFormatException,
    );
  });

  test('refuses one bad item instead of accepting the rest', () {
    final good = networkShare('alpha').toJson();
    // The last item is a document the receiver would refuse on its own.
    final bad = {...good, 'peers': <Object?>[]};

    expect(
      () => decodeShareItems(bundleJson([good, good, bad])),
      throwsFormatException,
    );
    expect(
      () => decodeShareItems(bundleJson(['not a document'])),
      throwsFormatException,
    );
  });

  test('refuses content larger than shareMaxBytes', () {
    final item = networkShare('alpha').toJson();

    expect(
      () => decodeShareItems(
        bundleJson([item, {...item, 'padding': 'x' * shareMaxBytes}]),
      ),
      throwsFormatException,
    );
  });

  test('a bundle is not a document, so an older app refuses it whole', () {
    final bundle = encodeShareItems([
      networkShare('alpha'),
      networkShare('beta'),
    ]);

    expect(() => ShareDocument.decode(bundle), throwsFormatException);
    expect(
      decodeShareItems(bundle).map((document) => document.name),
      ['alpha', 'beta'],
    );
  });
}
