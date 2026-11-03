part of 'home_controller.dart';

/// The traffic of every running instance, and the rates between two samples.
typedef TrafficSample = ({
  int received,
  int sent,
  double receiveRate,
  double sendRate,

  /// When this sample was taken, or null while nothing runs.
  DateTime? at,
});

/// Sums the peers of every running instance in [instances] and derives the
/// per-second rates from [previous].
///
/// The first sample has zero rates, a peer that restarted its counters cannot
/// produce a negative rate, and the rates restart at zero after the last
/// instance stopped.
TrafficSample measureTraffic(
  Map<String, Instance> instances,
  TrafficSample? previous,
) {
  var received = 0;
  var sent = 0;
  var running = 0;
  for (final instance in instances.values) {
    if (instance.status != InstanceStatus.running) continue;
    running++;
    for (final peer in instance.peers) {
      received += peer.rxBytes;
      sent += peer.txBytes;
    }
  }
  final now = DateTime.now();
  final sampledAt = previous?.at;
  final restarted =
      running == 0 ||
      sampledAt == null ||
      received < (previous?.received ?? 0) ||
      sent < (previous?.sent ?? 0);
  final seconds = restarted
      ? 0.0
      : now.difference(sampledAt).inMicroseconds /
            Duration.microsecondsPerSecond;
  final previousReceived = previous?.received ?? 0;
  final previousSent = previous?.sent ?? 0;
  return (
    received: received,
    sent: sent,
    receiveRate: seconds > 0
        ? max(0, received - previousReceived) / seconds
        : 0,
    sendRate: seconds > 0 ? max(0, sent - previousSent) / seconds : 0,
    at: running == 0 ? null : now,
  );
}
