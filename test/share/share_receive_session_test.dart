import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:yukari/share/share_document.dart';
import 'package:yukari/share/share_receive_session.dart';

import 'share_fixture.dart';

/// A sender for [data], built the way the share page builds one.
SendSession senderFor(Uint8List data, {int sliceSize = 200}) =>
    SendSession.forFile(
      data,
      filename: 'share.json',
      contentType: shareContentType,
      sliceSize: sliceSize,
    );

/// A frame carrying [block], encoded the way a sender encodes one.
String frameOf(EncodedBlock block) => base64.encode(blockToBinary(block));

/// Feeds frames of [sender] until the session completes, giving up after
/// [limit]; the outcomes, in order.
List<ScanOutcome> feed(
  ShareReceiveSession session,
  SendSession sender, {
  int limit = 200,
}) {
  final outcomes = <ScanOutcome>[];
  for (var i = 0; i < limit && !session.isComplete; i++) {
    outcomes.add(session.addScan(sender.next().payload));
  }
  return outcomes;
}

void main() {
  test('decodes a compressed share back to its content', () {
    final content = noiseNetworkShare(peers: 8).encode();
    final session = ShareReceiveSession();

    feed(session, senderFor(Uint8List.fromList(utf8.encode(content))));

    expect(session.isComplete, isTrue);
    expect(utf8.decode(session.result!.data), content);
    expect(session.result!.meta.contentType, shareContentType);
  });

  test('refuses a frame that names more blocks than a share holds', () {
    final session = ShareReceiveSession();

    final outcome = session.addScan(
      frameOf(
        EncodedBlock(
          k: 0xFFFFFFFF,
          bytes: 0xFFFFFFFF,
          checksum: 1,
          indices: [0],
          data: Uint8List(16),
        ),
      ),
    );

    expect(outcome, ScanOutcome.invalid);
    expect(session.k, 0, reason: 'nothing is allocated for it');
    expect(session.blockStatus, isEmpty);
  });

  test('refuses a frame whose block count does not match its size', () {
    final session = ShareReceiveSession();

    final outcome = session.addScan(
      frameOf(
        EncodedBlock(
          k: 5000,
          bytes: 100,
          checksum: 1,
          indices: [0],
          data: Uint8List(100),
        ),
      ),
    );

    expect(outcome, ScanOutcome.invalid);
    expect(session.k, 0);
  });

  test('refuses indices outside the transfer', () {
    final session = ShareReceiveSession();

    final outcome = session.addScan(
      frameOf(
        EncodedBlock(
          k: 2,
          bytes: 200,
          checksum: 1,
          indices: [0, 7],
          data: Uint8List(100),
        ),
      ),
    );

    expect(outcome, ScanOutcome.invalid);
  });

  test('stops inflating a payload at the largest share', () {
    // Megabytes of zeros deflate to a few KiB: a transfer that looks small
    // and would inflate far past any share.
    final bomb = Uint8List(8 * 1024 * 1024);
    final sender = senderFor(bomb, sliceSize: 400);
    expect(sender.encoder.bytes, lessThan(shareMaxTransferBytes));
    final session = ShareReceiveSession();

    final outcomes = feed(session, sender, limit: 400);

    expect(session.isComplete, isFalse);
    expect(session.decodedCount, session.k, reason: 'every block arrived');
    expect(outcomes, contains(ScanOutcome.invalid));
  });

  test('a new transfer replaces the one in progress', () {
    final session = ShareReceiveSession();
    final first = senderFor(
      Uint8List.fromList(utf8.encode(noiseNetworkShare(peers: 8).encode())),
      sliceSize: 100,
    );
    session.addScan(first.next().payload);
    final checksum = session.checksum;

    final second = senderFor(
      Uint8List.fromList(utf8.encode(sharedNetworkDocument().encode())),
    );
    final outcome = session.addScan(second.next().payload);

    expect(outcome, anyOf(ScanOutcome.started, ScanOutcome.complete));
    expect(session.checksum, isNot(checksum));
  });
}
