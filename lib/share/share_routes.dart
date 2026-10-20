import 'share_document.dart';

/// The route pattern that serves a sender; the kind and the id are the path
/// parameters the router parses.
const String shareSendRoutePattern = '/share/send/:kind/:id';

/// The location that streams [id] ([kind]) as a QR stream.
String shareSendPath(ShareKind kind, String id) =>
    '/share/send/${kind.name}/${Uri.encodeComponent(id)}';

/// The location that scans a share in from another device.
const String shareReceivePath = '/share/receive';
