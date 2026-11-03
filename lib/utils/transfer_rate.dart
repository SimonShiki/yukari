import 'dart:collection';

/// Estimates a byte rate the way the Qrs web app measures it.
///
/// The meter is fed "this many bytes moved" events and keeps their running
/// total as a counter. The rate is that counter's growth between the **oldest
/// and newest sample inside [_window]**, divided by the time between those two
/// samples — `useBytesRate` in the web app's `app/composables/timeseries.ts`
/// computes exactly this from its sampled counter.
///
/// Dividing by the observed span rather than by the window length is what makes
/// the reading usable from the first moments of a transfer: a stream that has
/// been running for 300 ms already reports the rate of those 300 ms, where a
/// fixed window would report a fraction of it and climb for a full window.
///
/// Two properties follow from measuring a *counter* rather than the work each
/// event releases:
///
/// * A stream at a steady rate reads a steady value, whatever the interval
///   between events.
/// * An event that releases a large amount of work at once is averaged over the
///   surrounding samples. Feed the counter only what really crossed the link,
///   or a burst shows up as a throughput no link could carry.
///
/// The estimate needs at least two samples spanning [_minimumSpan]; until then
/// it reports nothing rather than guessing from a single point.
class TransferRateMeter {
  /// Creates a meter.
  ///
  /// [nowMicros] is the time source, in microseconds since any fixed epoch,
  /// and exists so tests can drive the clock themselves. The default is a
  /// monotonic [DateTime.now] clock.
  TransferRateMeter({int Function()? nowMicros})
    : _nowMicros = nowMicros ?? monotonicMicroseconds();

  /// Length of the sliding window the rate is averaged over.
  ///
  /// Two seconds rather than the one the web app uses: this app can stream at
  /// 1 fps, and a 1 s window would never hold the two samples a rate needs.
  static const Duration _window = Duration(seconds: 2);

  /// Shortest stretch of time a rate is ever computed over.
  ///
  /// Two samples 10 ms apart say "10 ms of traffic", not a throughput: the
  /// floor keeps a burst that lands inside a single frame from reading as a
  /// multi-megabyte link.
  static const Duration _minimumSpan = Duration(milliseconds: 250);

  final int Function() _nowMicros;
  final Queue<({int micros, int total})> _samples = Queue();

  int _total = 0;
  int? _firstMicros;

  /// Time between the first recorded byte and now.
  ///
  /// It is the span a transfer's average speed divides its payload by; zero
  /// when nothing has been recorded since the last [clear].
  Duration get elapsed {
    final first = _firstMicros;
    if (first == null) return Duration.zero;
    final span = _nowMicros() - first;
    return span <= 0 ? Duration.zero : Duration(microseconds: span);
  }

  /// Bytes per second over the last [_window].
  ///
  /// Returns 0 until two samples spanning [_minimumSpan] are inside the window.
  /// Reading the meter prunes the samples that have aged out, so a transfer that
  /// stops falls back to zero on its own once less than one window of samples is
  /// left.
  double get bytesPerSecond {
    final nowMicros = _nowMicros();
    _prune(nowMicros);

    if (_samples.length < 2) return 0;

    final oldest = _samples.first;
    final newest = _samples.last;
    final span = newest.micros - oldest.micros;
    if (span < _minimumSpan.inMicroseconds) return 0;

    final bytes = newest.total - oldest.total;
    return bytes * Duration.microsecondsPerSecond / span;
  }

  /// Average bytes per second for [bytes] recovered since the first [record].
  ///
  /// A finished transfer has no "current" rate; its payload over the time it
  /// took is the number that stays true, and it is what the web app shows. A
  /// transfer that finished inside [_minimumSpan] divides by that floor rather
  /// than by zero.
  double averageBytesPerSecond(int bytes) {
    if (bytes <= 0) return 0;

    final span = elapsed.inMicroseconds;
    final denominator = span < _minimumSpan.inMicroseconds
        ? _minimumSpan.inMicroseconds
        : span;
    return bytes * Duration.microsecondsPerSecond / denominator;
  }

  /// Records that [bytes] moved at the current time.
  ///
  /// Non-positive amounts are ignored: they carry no information, and skipping
  /// them keeps the sample queue to one entry per really moving event.
  void record(int bytes) {
    if (bytes <= 0) return;

    final nowMicros = _nowMicros();
    _firstMicros ??= nowMicros;
    _total += bytes;
    _samples.add((micros: nowMicros, total: _total));
    _prune(nowMicros);
  }

  /// Forgets every sample and the counter, e.g. when the transfer is reset.
  void clear() {
    _samples.clear();
    _total = 0;
    _firstMicros = null;
  }

  /// Drops the samples that fell out of the window before [nowMicros].
  void _prune(int nowMicros) {
    final cutoff = nowMicros - _window.inMicroseconds;
    while (_samples.isNotEmpty && _samples.first.micros <= cutoff) {
      _samples.removeFirst();
    }
  }
}

/// A monotonic microsecond clock backed by [DateTime.now].
///
/// The returned timestamp never goes backwards: a system clock that is stepped
/// by a time sync cannot leave samples out of order inside the window. Tests
/// inject their own source instead of waiting on real time.
int Function() monotonicMicroseconds() {
  var last = -1;
  return () {
    final micros = DateTime.now().microsecondsSinceEpoch;
    if (micros < last) return last;
    last = micros;
    return micros;
  };
}
