part of 'qr_share_send_controller.dart';

/// The file name a share document carries on the wire.
const String _shareFileName = 'yukari-share.json';

/// The frame rate range the sender allows: slower only wastes screen time, and
/// no phone camera keeps up above 30 fps.
const int minShareFps = 5;
const int maxShareFps = 30;

/// The frame rate the sender starts at, from the display's [refreshRate].
///
/// A 30 fps camera needs each frame for about two capture intervals (~66 ms),
/// so 15 fps loses nothing to mid-change captures while halving the sender's
/// work. 15 divides 60, 90 and 120, and 24 divides 120 and 144, so the stream
/// keeps an even cadence on those displays; 24 fps is worth it only from
/// 120 Hz. An unknown or unusable rate takes 15.
int defaultShareFps(double refreshRate) {
  if (!refreshRate.isFinite || refreshRate <= 0) return 15;
  return refreshRate >= 120 ? 24 : 15;
}

/// How many frames a transfer is split into, traded against code density.
///
/// The block size follows the compressed document size instead of a fixed
/// number of bytes, because a masked share document is small: a fixed size sent
/// every one in a frame or two and let the choice only make that one code
/// denser. Easy splits the document into ~3 small codes a handheld camera reads
/// from farther away; Balanced sits in between; Fast sends the fewest, densest
/// codes. Fast cannot always be one frame: a single QR code carries only a few
/// hundred bytes, so a larger share stays at the fewest codes the presets allow.
///
/// [sliceSizeFor] floors the block at 32 bytes so a tiny share still gets codes
/// big enough to line up, and caps it per preset so the QR version a camera has
/// to resolve stays sane: about V20 for Easy, V25 for Balanced and V35 for Fast.
enum QrShareDensity {
  easy(3, maxSlice: 400),
  balanced(2, maxSlice: 800),
  fast(1, maxSlice: 1400);

  const QrShareDensity(this.targetFrames, {required this.maxSlice});

  /// The number of frames the document is split into, before [maxSlice] caps it.
  final int targetFrames;

  /// The largest block the preset draws, which caps its QR version.
  final int maxSlice;

  /// The block size that splits a [compressedBytes]-byte transfer into
  /// [targetFrames] fountain blocks, within the preset's slice limits.
  int sliceSizeFor(int compressedBytes) =>
      (compressedBytes / targetFrames).ceil().clamp(32, maxSlice).toInt();
}

/// The compressed size [SendSession.forFile] slices: the payload with its file
/// header, deflated exactly as the session does it, so a density preset's block
/// count is the block count the stream really has.
int _compressedTransferBytes(Uint8List payload) => createEncoder(
  appendFileHeaderMetaToBuffer(
    payload,
    const FileHeaderMeta(
      filename: _shareFileName,
      contentType: shareContentType,
    ),
  ),
  payload.length,
  compress: true,
).bytes;
