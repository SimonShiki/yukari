/// Where network instances run: inside the app through FFI, or inside the
/// privileged background service.
enum BackendKind { ffi, service }

/// Connection state of the active backend.
enum BackendStatus { connecting, ready, unavailable }

/// Installation state of the background system service.
enum ServiceState { unsupported, notInstalled, stopped, running }

/// Whether a network may create its TUN device under the active backend.
enum TunAccess {
  granted,

  /// The user declined the request, such as Android's VPN consent dialog.
  denied,

  /// The process lacks the privileges; see [NetworkBackend.elevate].
  elevationRequired,
}
