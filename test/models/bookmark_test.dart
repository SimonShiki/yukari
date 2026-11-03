import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/bookmark.dart';
import 'package:yukari_core/models/node.dart';

void main() {
  test('survives a JSON round trip', () {
    final original = Bookmark(
      id: 'b1',
      node: Node(
        id: 'relay',
        url: Uri.parse('wss://relay.example.com/path'),
        port: 11010,
        protocols: const [NodeProtocol.tcp, NodeProtocol.wss],
        publicKey: 'AAAA',
      ),
      name: 'Home relay',
      description: 'The one at home',
      category: 'Home',
      tags: const ['relay', 'fast'],
      extensions: const {
        'vendor': {'id': 7},
      },
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      updatedAt: DateTime.utc(2026, 1, 3, 3, 4, 5),
    );

    final restored = Bookmark.fromJson(original.toJson());

    expect(restored.id, 'b1');
    expect(restored.node.url.toString(), 'wss://relay.example.com/path');
    expect(restored.node.port, 11010);
    expect(restored.node.protocols, [NodeProtocol.tcp, NodeProtocol.wss]);
    expect(restored.node.publicKey, 'AAAA');
    expect(restored.name, 'Home relay');
    expect(restored.description, 'The one at home');
    expect(restored.category, 'Home');
    expect(restored.tags, ['relay', 'fast']);
    expect(restored.extensions, {
      'vendor': {'id': 7},
    });
    expect(restored.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(restored.updatedAt, DateTime.utc(2026, 1, 3, 3, 4, 5));
  });

  test('defaults the optional metadata', () {
    final bookmark = Bookmark(
      id: 'b1',
      node: Node(
        id: 'relay',
        url: Uri.parse('relay.example.com'),
        port: 11010,
        protocols: const [NodeProtocol.tcp],
      ),
    );

    expect(bookmark.tags, isEmpty);
    expect(bookmark.extensions, isEmpty);
    expect(bookmark.category, isNull);
    expect(bookmark.createdAt.isUtc, isTrue);
  });

  test('names itself after the node host when it has no name', () {
    final bookmark = Bookmark(
      id: 'b1',
      node: Node(
        id: 'relay',
        url: Uri.parse('relay.example.com'),
        port: 11010,
        protocols: const [NodeProtocol.tcp],
      ),
    );

    expect(bookmark.displayName, 'relay.example.com');
    expect(bookmark.address, 'relay.example.com:11010');
    bookmark.name = '  ';
    expect(bookmark.displayName, 'relay.example.com');
    bookmark.name = ' Home ';
    expect(bookmark.displayName, 'Home');
  });

  test('the copy kept by callers is independent of the original', () {
    final original = Node(
      id: 'relay',
      url: Uri.parse('relay.example.com'),
      port: 11010,
      protocols: [NodeProtocol.tcp],
      publicKey: 'AAAA',
    );

    // Adding a bookmark's node to a network must not alias the stored one.
    final copy = original.copy()
      ..port = 12010
      ..protocols.add(NodeProtocol.udp)
      ..publicKey = 'BBBB';

    expect(original.port, 11010);
    expect(original.protocols, [NodeProtocol.tcp]);
    expect(original.publicKey, 'AAAA');
    expect(copy.port, 12010);
    expect(copy.protocols, [NodeProtocol.tcp, NodeProtocol.udp]);
    expect(copy.publicKey, 'BBBB');
  });

  test('sameNode compares the address, not the metadata', () {
    Node node(String id, String host, int port) => Node(
      id: id,
      url: Uri.parse(host),
      port: port,
      protocols: const [NodeProtocol.tcp],
    );

    expect(
      sameNode(
        node('a', 'relay.example.com', 11010),
        node('b', 'relay.example.com', 11010),
      ),
      isTrue,
    );
    expect(
      sameNode(
        node('a', 'relay.example.com', 11010),
        node('a', 'relay.example.com', 12010),
      ),
      isFalse,
    );
    expect(
      sameNode(
        node('a', 'relay.example.com', 11010),
        node('a', 'other.example.com', 11010),
      ),
      isFalse,
    );
  });
}
