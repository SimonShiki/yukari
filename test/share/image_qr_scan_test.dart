import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qrs_dart/qrs_dart.dart';
import 'package:yukari/share/image_qr_scan.dart';
import 'package:yukari/share/share_document.dart';

import '../share/share_fixture.dart';

/// Bytes per QR module in the rendered test images: cameras need at least two,
/// the detector is comfortable with four, so five leaves no doubt.
const int _modulePixels = 5;

/// Renders a QR module matrix as a black-on-white bitmap.
img.Image renderMatrix(List<List<bool>> matrix, {int scale = _modulePixels}) {
  final side = matrix.length * scale;
  final image = img.Image(width: side, height: side);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));

  final black = img.ColorRgb8(0, 0, 0);
  for (var y = 0; y < matrix.length; y++) {
    for (var x = 0; x < matrix[y].length; x++) {
      if (!matrix[y][x]) continue;
      img.fillRect(
        image,
        x1: x * scale,
        y1: y * scale,
        x2: x * scale + scale - 1,
        y2: y * scale + scale - 1,
        color: black,
      );
    }
  }
  return image;
}

/// A sender for [document], the way the share page builds one.
SendSession senderFor(ShareDocument document, {int sliceSize = 200}) =>
    SendSession.forFile(
      Uint8List.fromList(utf8.encode(document.encode())),
      filename: 'share.json',
      contentType: shareContentType,
      sliceSize: sliceSize,
      compress: false,
    );

void main() {
  test('reads a still PNG back to the exact payload', () async {
    final sender = senderFor(sharedNetworkDocument());
    final frame = sender.next();

    final report = await decodeImageForQrPayloads(
      img.encodePng(renderMatrix(frame.qr.data)),
    );

    expect(report.frames, 1);
    expect(report.payloads, <String>[frame.payload]);
  });

  test('reports an empty result when the image has no QR code', () async {
    final blank = img.Image(width: 64, height: 64);
    img.fill(blank, color: img.ColorRgb8(255, 255, 255));

    final report = await decodeImageForQrPayloads(img.encodePng(blank));

    expect(report.frames, 1);
    expect(report.payloads, isEmpty);
  });

  test('rejects data that is not an image', () async {
    await expectLater(
      decodeImageForQrPayloads(Uint8List.fromList(<int>[1, 2, 3, 4])),
      throwsA(isA<FormatException>()),
    );
  });

  test('reads the fountain frames out of an exported animated GIF', () async {
    final document = sharedNetworkDocument();
    final framed = appendFileHeaderMetaToBuffer(
      Uint8List.fromList(utf8.encode(document.encode())),
      const FileHeaderMeta(
        filename: 'share.json',
        contentType: shareContentType,
      ),
    );
    const sliceSize = 100;
    final blockCount = SendSession(
      framed,
      sliceSize: sliceSize,
      compress: false,
    ).blockCount;
    final frames = blockCount * 3;

    final gif = await encodeGif(
      GifExportOptions(
        data: framed,
        sliceSize: sliceSize,
        frames: frames,
        fps: 20,
        size: 320,
        compress: false,
      ),
    );
    expect(gif, isNotNull);

    final report = await decodeImageForQrPayloads(gif!);
    expect(report.frames, frames);
    expect(report.payloads, isNotEmpty);

    // The payloads reconstruct the share through the real receiver, which is
    // the whole point of the image path on a platform without a camera.
    final receiver = ReceiveSession();
    for (final payload in report.payloads) {
      receiver.addScan(payload);
    }
    final result = receiver.result;
    expect(result, isNotNull);
    final decoded = ShareDocument.decode(utf8.decode(result!.data));
    expect(decoded.encode(), document.encode());
  });

  // The UI path on every platform with isolates: the scanner must hand the same
  // payloads back from a worker isolate as the pure decoder does in place.
  test('reads a still PNG through the worker isolate', () async {
    final sender = senderFor(sharedNetworkDocument());
    final frame = sender.next();

    final report = await scanImageForQrPayloads(
      img.encodePng(renderMatrix(frame.qr.data)),
    );

    expect(report.frames, 1);
    expect(report.payloads, <String>[frame.payload]);
  });

  test('a cancelled worker keeps the payloads found so far', () async {
    // A long animation: the scan must still be running when the poll notices
    // the cancellation, otherwise "stopped early" would be a coin flip.
    const frames = 120;
    final document = sharedNetworkDocument();
    final framed = appendFileHeaderMetaToBuffer(
      Uint8List.fromList(utf8.encode(document.encode())),
      const FileHeaderMeta(
        filename: 'share.json',
        contentType: shareContentType,
      ),
    );
    final gif = await encodeGif(
      GifExportOptions(
        data: framed,
        sliceSize: 100,
        frames: frames,
        fps: 20,
        size: 320,
        compress: false,
      ),
    );
    expect(gif, isNotNull);

    var cancelled = false;
    final found = <String>[];
    var examined = 0;
    var total = 0;
    final report = await scanImageForQrPayloads(
      gif!,
      onProgress: (done, count) {
        examined = done;
        total = count;
      },
      onPayload: (payload) {
        found.add(payload);
        // The scanner polls this from the UI isolate every 150 ms.
        cancelled = true;
      },
      isCancelled: () => cancelled,
    );

    expect(found, isNotEmpty);
    expect(total, frames);
    expect(report.payloads, found);
    // The worker was killed before examining every frame.
    expect(examined, lessThan(total));
  });
}
