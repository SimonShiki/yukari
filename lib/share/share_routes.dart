import 'share_bundle.dart';
import 'share_document.dart';

/// The route pattern that serves a sender; the kind and the id are the path
/// parameters the router parses.
const String shareSendRoutePattern = '/share/send/:kind/:id';

/// The location that streams [ids] ([kind]) as a QR stream.
///
/// The ids travel as one path component, comma-joined and percent-encoded, so
/// go_router's single decode yields the joined string back. One id encodes to
/// its own text, so a single-target link stays a plain id.
String shareSendPaths(ShareKind kind, List<String> ids) =>
    '/share/send/${kind.name}/${Uri.encodeComponent(ids.join(','))}';

/// The location that streams [id] ([kind]) as a QR stream.
String shareSendPath(ShareKind kind, String id) => shareSendPaths(kind, [id]);

/// The ids [shareSendPaths] wrote, read back from the route's `:id` parameter.
///
/// Ids are comma-free — a saved uuid or a `host:port` — so a comma separates
/// them without an escape, and an empty one is dropped. A link naming more than
/// [shareMaxBundleItems] carries the first ones.
List<String> shareSendIds(String? raw) => raw == null
    ? const <String>[]
    : raw
          .split(',')
          .where((id) => id.isNotEmpty)
          .take(shareMaxBundleItems)
          .toList();

/// The location that scans a share in from another device.
const String shareReceivePath = '/share/receive';
