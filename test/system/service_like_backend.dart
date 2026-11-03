import 'package:yukari_core/models/models.dart';

import '../fake_backend.dart';

/// A backend that behaves like the background service: every call takes a
/// moment, and a collection can fail the way a busy or reconnecting service
/// does.
final class ServiceLikeBackend extends FakeBackend {
  ServiceLikeBackend({
    this.delay = const Duration(milliseconds: 5),
    this.collectFailures = 0,
  });

  /// How long each backend call takes.
  final Duration delay;

  /// How many coming collections throw instead of answering.
  int collectFailures;

  /// How many start and stop requests arrived.
  int starts = 0;
  int stops = 0;

  Future<void> _wait() => Future<void>.delayed(delay);

  @override
  Future<Map<String, String>> collectInfos() async {
    await _wait();
    if (collectFailures > 0) {
      collectFailures--;
      throw StateError('the service did not answer');
    }
    return super.collectInfos();
  }

  @override
  Future<void> start(String id, Network network) async {
    starts++;
    await _wait();
    if (started.containsKey(id)) {
      throw StateError('an instance with this name already runs');
    }
    await super.start(id, network);
  }

  @override
  Future<void> stop(List<String> names) async {
    stops++;
    await _wait();
    await super.stop(names);
  }
}
