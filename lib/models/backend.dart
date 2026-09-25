enum BackendKind { ffi, rpc }

enum BackendStatus { stopped, starting, running, stopping, failed, closed }

final class Backend {
  Backend({
    this.kind = BackendKind.ffi,
    this.status = BackendStatus.stopped,
    this.error,
    this.updatedAt,
  });

  final BackendKind kind;
  final BackendStatus status;
  final String? error;
  final DateTime? updatedAt;
}
