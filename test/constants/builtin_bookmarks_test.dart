import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/constants/builtin_bookmarks.dart';

/// The community shared nodes the app ships with, and the category and tags
/// the bookmarks page filters them by.
void main() {
  test('ships every community node once, with the monitored endpoint', () {
    expect(
      {
        for (final bookmark in builtinBookmarks)
          bookmark.address: bookmark.node.protocols.single.name,
      },
      {
        '225284.xyz:11010': 'tcp',
        '183.230.36.171:11010': 'tcp',
        'easytier.weiai.org.cn:11010': 'tcp',
        'et.chinokou.cn:443': 'wss',
        'et.basd1.de:11010': 'udp',
        'us01.225284.xyz:11010': 'udp',
      },
    );

    final ids = builtinBookmarks.map((bookmark) => bookmark.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.every((id) => id.startsWith(builtinBookmarkIdPrefix)), isTrue);
  });

  test('serializes each peer as the address the monitor verified', () {
    expect(
      [
        for (final bookmark in builtinBookmarks)
          for (final protocol in bookmark.node.protocols)
            bookmark.node.endpoint(protocol).toString(),
      ],
      [
        'tcp://225284.xyz:11010',
        'tcp://183.230.36.171:11010',
        'tcp://easytier.weiai.org.cn:11010',
        'wss://et.chinokou.cn:443',
        'udp://et.basd1.de:11010',
        'udp://us01.225284.xyz:11010',
      ],
    );
  });

  test('is a read-only shared node carrying its operator, and relays', () {
    for (final bookmark in builtinBookmarks) {
      expect(bookmark.category, sharedNodeCategory);
      expect(bookmark.tags, contains(sharedNodeRelayTag));
      expect(bookmark.name, isNotNull);
      expect(bookmark.name, isNotEmpty);
      expect(isBuiltinBookmark(bookmark), isTrue);
    }
  });

  test('tags only the nodes served from overseas', () {
    expect(
      [
        for (final bookmark in builtinBookmarks)
          if (bookmark.tags.contains(sharedNodeOverseasTag)) bookmark.address,
      ],
      ['us01.225284.xyz:11010'],
    );
  });
}
