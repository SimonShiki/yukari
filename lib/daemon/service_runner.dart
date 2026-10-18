import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../backend/ffi_backend.dart';
import '../backend/system/system_service.dart';
import '../storage/network_store.dart';
import '../system/magic_dns.dart';
import '../system/magic_dns_auto.dart';
import 'service_daemon.dart';
import 'service_socket.dart';
import 'windows_service_host.dart';

/// The environment variable the Android module starts this service with.
const _androidDnsEnv = 'YUKARI_ANDROID_DNS';

/// The system DNS of the platform this service runs on.
///
/// Android's module runs this Linux build as root, where only packet
/// interception can send a zone's lookups to Magic DNS, so the module marks
/// the process. Elsewhere the service's own platform decides.
MagicDnsSetup? _magicDns() => Platform.environment[_androidDnsEnv] == '1'
    ? MagicDnsAuto(system: MagicDnsSystem(platform: MagicDnsPlatform.android))
    : null;

/// Runs the service for the data directory [dataDir] until the OS stops it,
/// or until SIGINT or SIGTERM in the console.
Future<void> runService({required String dataDir, int? ownerUid}) async {
  Future<void> serve(Future<void> stopping, void Function(String) log) async {
    final daemon = ServiceDaemon(
      store: NetworkStore.inDirectory(dataDir, readOnly: true),
      backend: FfiBackend(),
      magicDns: _magicDns(),
      log: log,
    );
    final (socket, token) = await bindServiceSocket(
      dataDir: dataDir,
      ownerUid: ownerUid,
    );
    await daemon.start(socket, token: token);
    await stopping;
    await daemon.stop();
  }

  if (Platform.isWindows) {
    _prepareWindows();
    final log = _fileLog(dataDir);
    if (await runWindowsService(
      SystemService.name,
      (stopping) => serve(stopping, log),
    )) {
      return;
    }
  }
  final stopping = Completer<void>();
  final signals =
      [ProcessSignal.sigint, if (!Platform.isWindows) ProcessSignal.sigterm]
          .map(
            (signal) => signal.watch().listen((_) {
              if (!stopping.isCompleted) stopping.complete();
            }),
          )
          .toList();
  try {
    await serve(stopping.future, stderr.writeln);
  } finally {
    for (final subscription in signals) {
      await subscription.cancel();
    }
  }
}

/// Lets EasyTier find its DLLs, which sit in `../lib` beside the bundled
/// FFI library rather than in the default DLL search path.
void _prepareWindows() {
  final bin = p.dirname(Platform.resolvedExecutable);
  // Services start in System32; run from the executable's directory instead.
  Directory.current = bin;
  final setDllDirectory = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<
        Int32 Function(Pointer<Utf16>),
        int Function(Pointer<Utf16>)
      >('SetDllDirectoryW');
  using((arena) {
    final lib = p.normalize(p.join(bin, '..', 'lib'));
    setDllDirectory(lib.toNativeUtf16(allocator: arena));
  });
}

/// Logs into the data directory, as a Windows service has no console.
void Function(String) _fileLog(String dataDir) {
  final file = File(p.join(dataDir, 'service.log'));
  if (file.existsSync() && file.lengthSync() > 1 << 20) file.deleteSync();
  return (message) => file.writeAsStringSync(
    '${DateTime.now().toIso8601String()} $message\n',
    mode: FileMode.append,
  );
}
