import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Longest edge an image is scaled down to before QR detection.
///
/// A phone screenshot or a photo can be several thousand pixels wide; the
/// detector does not need that resolution, and the scan stays responsive.
const int _maxScanDimension = 1600;

/// The largest image file a scan reads.
const int maxScanImageBytes = 32 * 1024 * 1024;

/// The most pixels one decoded frame may have: a 50 MP photo, about 200 MiB
/// decoded. Images declare their size, so a small file could claim far more.
const int _maxFramePixels = 50 * 1000 * 1000;

/// The most pixels a scan decodes across every frame. The share page's GIF is
/// a few hundred 512 x 512 frames; an animation past this budget is only
/// scanned up to it.
const int _maxScanPixels = 1 << 28;

/// What one image scan produced.
class ImageScanReport {
  /// Creates a report.
  const ImageScanReport({required this.frames, required this.payloads});

  /// Number of image frames examined (an animated GIF has more than one).
  final int frames;

  /// Every QR payload found, in frame order.
  final List<String> payloads;
}

/// Decodes every QR code in [bytes] and returns the payloads it found.
///
/// The image may be a still bitmap (PNG, JPEG, BMP, WebP) or an animated GIF —
/// including the GIF exported by the share page. Decoding is pure Dart, so it
/// needs no camera and no plugin.
///
/// This runs on the **current** isolate and is CPU bound, so a UI caller should
/// use [scanImageForQrPayloads] instead, which moves the work to a worker
/// isolate. A caller that decodes in place gets the same progress reports it
/// would get from the worker.
///
/// [onProgress] is called once per examined frame with `(done, total)`,
/// [onPayload] as soon as a frame decodes, and [isCancelled] lets a long
/// animation stop early.
Future<ImageScanReport> decodeImageForQrPayloads(
  Uint8List bytes, {
  void Function(int done, int total)? onProgress,
  void Function(String payload)? onPayload,
  bool Function()? isCancelled,
}) async {
  if (bytes.length > maxScanImageBytes) {
    throw const FormatException('The image is too large to scan');
  }
  final decoder = _decoderFor(bytes);
  final info = decoder?.startDecode(bytes);
  if (decoder == null || info == null) {
    throw const FormatException('Unsupported or corrupt image data');
  }
  if (info.width * info.height > _maxFramePixels) {
    throw const FormatException('The image is too large to scan');
  }

  // Frames are decoded one at a time, so only one is ever held in memory. The
  // share page's GIF, like most, stores every frame whole.
  final framePixels = info.width * info.height;
  final total = min(
    max(decoder.numFrames(), 1),
    framePixels == 0 ? 1 : max(_maxScanPixels ~/ framePixels, 1),
  );
  final payloads = <String>[];

  for (var index = 0; index < total; index++) {
    if (isCancelled?.call() ?? false) break;
    final frame = decoder.decodeFrame(index);
    if (frame == null) {
      if (index == 0) {
        throw const FormatException('Unsupported or corrupt image data');
      }
      break;
    }
    final payload = _decodeQrPayload(frame);
    if (payload != null) {
      payloads.add(payload);
      onPayload?.call(payload);
    }
    onProgress?.call(index + 1, total);
    // Hand the event loop back between frames so an in-place caller can paint
    // the progress it was just given.
    await Future<void>.delayed(Duration.zero);
  }

  return ImageScanReport(frames: total, payloads: payloads);
}

/// The decoder for [bytes], made to refuse any frame over [_maxFramePixels]
/// before it allocates one, the declared canvas being only checked above.
img.Decoder? _decoderFor(Uint8List bytes) {
  final previous = img.Decoder.defaultMaxPixels;
  // Decoders read the default when they are made, and nothing runs between.
  img.Decoder.defaultMaxPixels = _maxFramePixels;
  try {
    return img.findDecoderForData(bytes);
  } finally {
    img.Decoder.defaultMaxPixels = previous;
  }
}

/// Decodes a single QR code from [frame], or returns `null` when there is none.
///
/// Detection uses ZXing's hybrid binarizer with the `tryHarder` hint, and falls
/// back to the global histogram binarizer, which copes better with the flat,
/// synthetic frames the sender produces.
String? _decodeQrPayload(img.Image frame) {
  final source = _luminanceOf(frame);
  final hints = DecodeHints()..put(DecodeHintType.tryHarder);

  for (final Binarizer binarizer in <Binarizer>[
    HybridBinarizer(source),
    GlobalHistogramBinarizer(source),
  ]) {
    try {
      return QRCodeReader().decode(BinaryBitmap(binarizer), hints: hints).text;
    } on ReaderException {
      continue;
    }
  }
  return null;
}

/// Converts [frame] to the ARGB pixel buffer ZXing's luminance source wants,
/// downscaling very large images first.
RGBLuminanceSource _luminanceOf(img.Image frame) {
  var source = frame;
  final longest = source.width > source.height ? source.width : source.height;
  if (longest > _maxScanDimension) {
    final scale = _maxScanDimension / longest;
    source = img.copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }

  final rgba = source.getBytes(order: img.ChannelOrder.rgba);
  final pixels = Int32List(source.width * source.height);
  for (var index = 0, offset = 0; index < pixels.length; index++, offset += 4) {
    pixels[index] =
        (0xff << 24) |
        (rgba[offset] << 16) |
        (rgba[offset + 1] << 8) |
        rgba[offset + 2];
  }
  return RGBLuminanceSource(source.width, source.height, pixels);
}
