import 'dart:convert';
import 'dart:io' show RawZLibFilter;
import 'dart:typed_data';

import 'package:qrs_dart/qrs_dart.dart';

import 'share_document.dart';

/// The most bytes a share transfer reassembles or inflates to: the largest
/// share, with room for the file header the sender wraps it in.
const int shareMaxTransferBytes = shareMaxBytes + 4096;

/// Collects the QR frames of one share until the transfer completes.
///
/// Wraps qrs's `ReceiveSession` to bound every size. A frame's header is the
/// sender's word: qrs allocates whatever block count it names, and inflates the
/// payload however large it grows. Here a header that no share could carry is
/// refused before anything is allocated, and the payload is inflated no further
/// than the largest share.
class ShareReceiveSession {
  final Set<String> _cached = <String>{};
  LtDecoder? _decoder;
  ReceiveResult? _result;
  int _sliceSize = 0;

  /// Number of encoded blocks the current transfer needs.
  int get k => _decoder?.meta?.k ?? 0;

  /// Payload size in bytes of the current transfer, as sent.
  int get bytes => _decoder?.meta?.bytes ?? 0;

  /// CRC32/XOR checksum identifying the current transfer.
  int get checksum => _decoder?.meta?.checksum ?? 0;

  /// The decoded transfer, once [addScan] returned [ScanOutcome.complete].
  ReceiveResult? get result => _result;

  /// Whether the current transfer has been fully decoded.
  bool get isComplete => _result != null;

  /// Number of accepted (non-duplicate) encoded blocks.
  int get encodedCount => _decoder?.encodedCount ?? 0;

  /// Number of decoded original blocks.
  int get decodedCount => _decoder?.decodedCount ?? 0;

  /// Per-block status: `1` when decoded, the degree of a pending block, `0`
  /// when nothing is known about that block yet.
  List<int> get blockStatus {
    final status = List<int>.filled(k, 0);
    final decoder = _decoder;
    if (decoder == null) return status;
    for (var i = 0; i < k; i++) {
      if (decoder.decodedData[i] != null) status[i] = 1;
    }
    for (final block in decoder.encodedBlocks) {
      for (final index in block.indices) {
        if (status[index] == 0 || status[index] > block.indices.length) {
          status[index] = block.indices.length;
        }
      }
    }
    return status;
  }

  /// Feeds one raw QR payload (with or without its URL prefix) into the session.
  ScanOutcome addScan(String rawData) {
    var data = rawData;
    if (data.startsWith('http')) {
      final hash = data.indexOf('#');
      data = hash < 0 ? '' : data.substring(hash + 1);
    }
    if (data.isEmpty) return ScanOutcome.empty;
    if (_cached.contains(data)) return ScanOutcome.duplicate;

    final EncodedBlock block;
    try {
      block = binaryToBlock(base64.decode(base64.normalize(data)));
    } on Object {
      return ScanOutcome.invalid;
    }
    if (!_plausible(block)) return ScanOutcome.invalid;

    var outcome = ScanOutcome.accepted;
    if (_decoder == null || block.checksum != checksum) {
      _decoder = LtDecoder();
      _result = null;
      _sliceSize = block.data.length;
      _cached.clear();
      outcome = ScanOutcome.started;
    } else if (_result != null) {
      return ScanOutcome.duplicate;
    } else if (block.k != k ||
        block.bytes != bytes ||
        block.data.length != _sliceSize) {
      // The same transfer cannot change its shape halfway.
      return ScanOutcome.invalid;
    }

    _cached.add(data);
    final decoder = _decoder!;
    if (!decoder.addBlock(block)) return outcome;
    final payload = _reassemble(decoder);
    if (payload == null) return ScanOutcome.invalid;
    try {
      final (data: content, :meta) = readFileHeaderMetaFromBuffer(payload);
      _result = ReceiveResult(data: content, meta: meta);
    } on Object {
      return ScanOutcome.invalid;
    }
    return ScanOutcome.complete;
  }

  /// Forgets the current transfer.
  void reset() {
    _decoder = null;
    _result = null;
    _cached.clear();
    _sliceSize = 0;
  }

  /// Whether [block]'s header describes a transfer a share fits in: a block
  /// count that matches its size and slice, and indices within it.
  static bool _plausible(EncodedBlock block) {
    final slice = block.data.length;
    if (slice == 0 || block.bytes < 1) return false;
    if (block.bytes > shareMaxTransferBytes) return false;
    if (block.k != (block.bytes + slice - 1) ~/ slice) return false;
    final indices = block.indices;
    if (indices.isEmpty || indices.length > block.k) return false;
    if (indices.any((index) => index >= block.k)) return false;
    return indices.toSet().length == indices.length;
  }

  /// The sender's payload out of the decoded blocks, or null when it fails
  /// the checksum. Like qrs, the zlib form is tried first, then the raw one.
  Uint8List? _reassemble(LtDecoder decoder) {
    final meta = decoder.meta!;
    final merged = Uint8List(meta.bytes);
    for (var i = 0; i < meta.k; i++) {
      final start = i * _sliceSize;
      final end = start + _sliceSize < merged.length
          ? start + _sliceSize
          : merged.length;
      merged.setRange(start, end, decoder.decodedData[i]!);
    }
    final inflated = _inflate(merged, shareMaxTransferBytes);
    if (inflated != null && getChecksum(inflated, meta.k) == meta.checksum) {
      return inflated;
    }
    return getChecksum(merged, meta.k) == meta.checksum ? merged : null;
  }
}

/// [data] inflated from zlib, or null when it is not a zlib stream or would
/// grow past [maxBytes]: the output is counted as it is produced, so a
/// stream that expands a thousandfold stops at the limit.
Uint8List? _inflate(Uint8List data, int maxBytes) {
  final filter = RawZLibFilter.inflateFilter();
  final output = BytesBuilder(copy: false);
  try {
    filter.process(data, 0, data.length);
    for (var end = false; ; end = true) {
      List<int>? chunk;
      while ((chunk = filter.processed(flush: true, end: end)) != null) {
        if (output.length + chunk!.length > maxBytes) return null;
        output.add(chunk);
      }
      if (end) break;
    }
  } on Object {
    return null;
  }
  return output.takeBytes();
}
