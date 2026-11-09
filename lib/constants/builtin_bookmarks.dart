import 'package:yukari_core/models/bookmark.dart';
import 'package:yukari_core/models/node.dart';

/// Ids of the built-in shared nodes start with this, so the rest of the app
/// can tell them from the user's own bookmarks: they are read-only and are
/// never written to `bookmarks.json`.
const String builtinBookmarkIdPrefix = 'builtin:';

/// The category every built-in shared node carries.
const String sharedNodeCategory = '公益节点';

/// Tag on a shared node that relays traffic for peers which cannot reach each
/// other directly.
const String sharedNodeRelayTag = 'relay';

/// Tag on a shared node hosted outside mainland China.
const String sharedNodeOverseasTag = 'overseas';

/// Publicly served EasyTier nodes offered out of the box, so a new network
/// has somewhere to connect without hunting for an address.
///
/// Community contributed, taken from the third-party monitor at
/// https://info.qtet.cn/uptime/easytier, which also reports each node's
/// operator, location and relay support. Every entry answered an EasyTier
/// handshake and held the connection for a full monitor window, secure-mode
/// clients included, and every one of them relays.
///
/// Community nodes come and go, so an entry may go dead between releases; the
/// bookmarks page lists them under "Shared Nodes". Public relays can see
/// connection metadata and may be untrusted, so consider pinning a
/// `publicKey` on entries that support it.
final List<Bookmark> builtinBookmarks = [
  sharedNode(
    id: '225284.xyz',
    name: '海波 · Shanghai Telecom',
    url: 'tcp://225284.xyz:11010',
    tags: const [sharedNodeRelayTag],
  ),
  sharedNode(
    id: '183.230.36.171',
    name: 'Just the Two of Us · Chongqing Mobile',
    url: 'tcp://183.230.36.171:11010',
    tags: const [sharedNodeRelayTag],
  ),
  sharedNode(
    id: 'easytier.weiai.org.cn',
    name: '为爱唯爱 · Xiamen Telecom',
    url: 'tcp://easytier.weiai.org.cn:11010',
    tags: const [sharedNodeRelayTag],
  ),
  sharedNode(
    id: 'et.chinokou.cn',
    name: 'ChinoKou · EdgeOne CDN',
    url: 'wss://et.chinokou.cn:443',
    tags: const [sharedNodeRelayTag],
  ),
  sharedNode(
    id: 'et.basd1.de',
    name: '宇智波希 · Zaozhuang BGP',
    url: 'udp://et.basd1.de:11010',
    tags: const [sharedNodeRelayTag],
  ),
  sharedNode(
    id: 'us01.225284.xyz',
    name: '海波 · US',
    url: 'udp://us01.225284.xyz:11010',
    tags: const [sharedNodeRelayTag, sharedNodeOverseasTag],
  ),
];

/// Whether [bookmark] is one of [builtinBookmarks] rather than a saved one.
bool isBuiltinBookmark(Bookmark bookmark) =>
    bookmark.id.startsWith(builtinBookmarkIdPrefix);

/// Builds one entry of [builtinBookmarks].
Bookmark sharedNode({
  required String id,
  required String name,
  required String url,
  String? description,
  String? category = sharedNodeCategory,
  String? publicKey,
  List<String> tags = const [],
}) => Bookmark(
  id: '$builtinBookmarkIdPrefix$id',
  node: Node(name: name, url: Uri.parse(url), publicKey: publicKey),
  name: name,
  description: description,
  category: category,
  tags: tags,
);
