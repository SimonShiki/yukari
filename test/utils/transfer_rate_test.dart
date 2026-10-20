import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/utils/transfer_rate.dart';

void main() {
  late int now;
  late TransferRateMeter meter;

  setUp(() {
    now = 0;
    meter = TransferRateMeter(nowMicros: () => now);
  });

  test('reports nothing from a single sample', () {
    expect(meter.bytesPerSecond, 0);

    meter.record(1000);
    expect(meter.bytesPerSecond, 0);
  });

  test('reports nothing until two samples span the minimum span', () {
    meter.record(1000);
    now = 100000;
    meter.record(1000);

    // Two samples 100 ms apart are below the 250 ms floor: a burst, not a rate.
    expect(meter.bytesPerSecond, 0);

    now = 300000;
    meter.record(1000);

    // 2 000 bytes between the oldest and newest sample, 300 ms apart.
    expect(meter.bytesPerSecond, closeTo(2000 / 0.3, 0.01));
  });

  test('a steady stream reads a steady rate', () {
    for (var sample = 0; sample < 12; sample++) {
      meter.record(1024);
      now += 100000;
    }

    // 1 KiB every 100 ms is 10 KiB/s, regardless of how often it is read.
    expect(meter.bytesPerSecond, closeTo(10240, 1));
    expect(meter.bytesPerSecond, closeTo(10240, 1));
  });

  test('samples age out of the window and a stopped stream reads zero', () {
    for (var sample = 0; sample < 4; sample++) {
      meter.record(1024);
      now += 100000;
    }
    expect(meter.bytesPerSecond, greaterThan(0));

    // Half a window later the early samples are gone but a rate remains.
    now += 1000000;
    expect(meter.bytesPerSecond, greaterThan(0));

    // A whole window with no new bytes leaves nothing to average.
    now += 2000000;
    expect(meter.bytesPerSecond, 0);
  });

  test('elapsed runs from the first recorded byte', () {
    expect(meter.elapsed, Duration.zero);

    meter.record(1000);
    now = 250000;
    expect(meter.elapsed, const Duration(milliseconds: 250));

    now = 1000000;
    meter.record(2000);
    expect(meter.elapsed, const Duration(seconds: 1));

    meter.clear();
    expect(meter.elapsed, Duration.zero);
  });

  test('average divides the transfer by its span, floored at the minimum', () {
    expect(meter.averageBytesPerSecond(0), 0);
    expect(meter.averageBytesPerSecond(-1), 0);

    // No byte recorded yet: the floor keeps a single-frame transfer finite.
    expect(meter.averageBytesPerSecond(1000), closeTo(4000, 0.01));

    meter.record(1000);
    now = 250000;
    expect(meter.averageBytesPerSecond(1000), closeTo(4000, 0.01));

    now = 2000000;
    expect(meter.averageBytesPerSecond(4000), closeTo(2000, 0.01));
  });

  test('ignores non-positive amounts', () {
    meter.record(0);
    meter.record(-1024);

    expect(meter.elapsed, Duration.zero);
    expect(meter.bytesPerSecond, 0);
  });

  test('clear forgets every sample and the counter', () {
    meter.record(1000);
    now = 500000;
    meter.record(2000);
    expect(meter.bytesPerSecond, greaterThan(0));

    meter.clear();

    expect(meter.elapsed, Duration.zero);
    expect(meter.bytesPerSecond, 0);
    expect(meter.averageBytesPerSecond(1000), closeTo(4000, 0.01));
  });

  test('the default clock never goes backwards', () {
    final clock = monotonicMicroseconds();

    final first = clock();
    final second = clock();

    expect(second, greaterThanOrEqualTo(first));
  });
}
