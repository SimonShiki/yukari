import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'udp_broadcast_capture.dart';
import 'udp_broadcast_interfaces.dart';
import 'udp_broadcast_linux_ffi.dart';

typedef RelayWorkerCommand = (List<RelayRegistration>, SendPort);

/// Owns a single capture isolate. Commands are serialized and acknowledged
/// before the next eventfd write, so each wake has exactly one command.
final class UdpBroadcastWorker {
  UdpBroadcastWorker(this.log);

  final void Function(String) log;
  _WorkerConnection? _worker;
  Future<void> _queue = Future.value();

  Future<void> update(List<RelayRegistration> registrations) {
    final next = _queue.then((_) async {
      if (_worker case final worker? when worker.exited.isCompleted) {
        _worker = null;
      }
      if (_worker == null && registrations.isEmpty) return;
      final worker = _worker ??= await _WorkerConnection.open(log);
      await worker.update(registrations);
      if (registrations.isEmpty) {
        await worker.exited.future;
        _worker = null;
      }
    });
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}

final class _WorkerConnection {
  _WorkerConnection(this.fd, this.events, this.log);

  final int fd;
  final ReceivePort events;
  final void Function(String) log;
  final ready = Completer<SendPort?>();
  final exited = Completer<void>();

  static Future<_WorkerConnection> open(void Function(String) log) async {
    final fd = checkedFd(LinuxRelayLibc.eventfd(0, nonblockCloexec), 'eventfd');
    final events = ReceivePort();
    final worker = _WorkerConnection(fd, events, log);
    events.listen(worker._event);
    try {
      await Isolate.spawn(
        _runWorker,
        (fd, events.sendPort),
        onExit: events.sendPort,
        onError: events.sendPort,
        debugName: 'UDP broadcast relay',
      );
    } catch (_) {
      worker._event(null);
      rethrow;
    }
    if (await worker.ready.future == null) {
      throw StateError('UDP broadcast relay worker exited during startup');
    }
    return worker;
  }

  void _event(Object? message) {
    switch (message) {
      case SendPort port:
        ready.complete(port);
      case String text:
        log(text);
      case List<Object?> error:
        log('UDP broadcast relay worker failed: ${error.first}');
      case null:
        LinuxRelayLibc.close(fd);
        events.close();
        if (!ready.isCompleted) ready.complete(null);
        exited.complete();
    }
  }

  Future<void> update(List<RelayRegistration> registrations) async {
    final port = await ready.future;
    if (port == null || exited.isCompleted) {
      throw StateError('UDP broadcast relay worker has exited');
    }
    final reply = ReceivePort();
    try {
      port.send((registrations, reply.sendPort));
      using((arena) {
        final value = arena<Uint64>()..value = 1;
        int written;
        do {
          written = LinuxRelayLibc.write(fd, value.cast(), sizeOf<Uint64>());
        } while (written < 0 && LinuxRelayLibc.errno == eintr);
        checkedFd(written, 'wake UDP broadcast relay worker');
      });
      final acknowledged = await Future.any([
        reply.first.then((_) => true),
        exited.future.then((_) => false),
      ]);
      if (!acknowledged && registrations.isNotEmpty) {
        throw StateError(
          'UDP broadcast relay worker exited before updating targets',
        );
      }
    } finally {
      reply.close();
    }
  }
}

Future<void> _runWorker((int, SendPort) initialization) async {
  final (eventFd, events) = initialization;
  final messages = ReceivePort();
  final commands = StreamIterator(messages.cast<RelayWorkerCommand>());
  try {
    final capture = BroadcastCapture.open(
      eventFd,
      (message) => events.send(message),
    );
    try {
      events.send(messages.sendPort);
      while (true) {
        if (!capture.poll()) continue;
        // poll consumed a wake. Yield to Dart to receive its matching command
        // even when the isolate message was still in transit at the wake.
        if (!await commands.moveNext()) break;
        final (registrations, reply) = commands.current;
        if (registrations.isEmpty) {
          reply.send(null);
          break;
        }
        capture.configure(registrations);
        reply.send(null);
      }
    } finally {
      capture.dispose();
    }
  } finally {
    messages.close();
    await commands.cancel();
  }
}
