import '../models/bookmark.dart';
import '../models/node.dart';

/// Ids of the built-in shared nodes start with this, so the rest of the app
/// can tell them from the user's own bookmarks: they are read-only and are
/// never written to `bookmarks.json`.
const String builtinBookmarkIdPrefix = 'builtin:';

/// Publicly served EasyTier nodes offered out of the box, so a new network
/// has somewhere to connect without hunting for an address.
///
/// Deliberately empty for now: EasyTier publishes no official public node
/// (its docs only use `<SharedNodeIP>` placeholders), and the community ones
/// move around, so shipping addresses here would hand users dead peers. Add
/// entries with [sharedNode] and an id prefixed [builtinBookmarkIdPrefix];
/// the bookmarks page lists them under "Shared Nodes" and the editor's "no
/// initial peers" tip offers them as one-tap additions.
///
/// Candidates to check before adding, from the EasyTier community: the
/// third-party list at https://info.qtet.cn/uptime/easytier and the
/// "shared nodes" discussion on the EasyTier repository. Public relays can
/// see connection metadata and may be untrusted, so consider pinning a
/// `publicKey` on entries that support it.
final List<Bookmark> builtinBookmarks = [];

/// Whether [bookmark] is one of [builtinBookmarks] rather than a saved one.
bool isBuiltinBookmark(Bookmark bookmark) =>
    bookmark.id.startsWith(builtinBookmarkIdPrefix);

/// Builds one entry of [builtinBookmarks].
Bookmark sharedNode({
  required String id,
  required String name,
  required String host,
  required int port,
  required List<NodeProtocol> protocols,
  String? description,
  String? category,
  String? publicKey,
  List<String> tags = const [],
}) => Bookmark(
  id: '$builtinBookmarkIdPrefix$id',
  node: Node(
    id: id,
    url: Uri.parse(host),
    port: port,
    protocols: protocols,
    publicKey: publicKey,
  ),
  name: name,
  description: description,
  category: category,
  tags: tags,
);
