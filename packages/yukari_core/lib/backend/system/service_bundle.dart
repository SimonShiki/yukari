import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Replaces [root] with a copy of the bundle around [executable], and returns
/// the copy of [executable] to register with the OS.
///
/// The service runs with full privileges, so it must run from where only
/// administrators write, never from the app's own files: a development build,
/// an unpacked archive or an AppImage lives where its user writes, and
/// whoever replaces the file the OS starts gains those privileges.
///
/// [executable] is the app's `bin/yukari-service`; the service finds its
/// native libraries in the `lib` directory beside that `bin`, so the copy
/// keeps the same layout. With [library], only the libraries whose names it
/// accepts are copied from `lib`, and staging fails when there are none.
Future<String> stageBundle(
  String executable,
  String root, {
  bool Function(String name)? library,
}) async {
  final bin = File(executable).parent;
  final lib = Directory(p.join(bin.parent.path, 'lib'));
  // Copies keep their source's mode, less the umask, so no copy is left
  // writable to others whatever the caller's umask or the source's mode.
  final previous = Platform.isWindows ? null : _umask(0x12 /* 022 */);
  try {
    final directory = Directory(root);
    if (await directory.exists()) await directory.delete(recursive: true);
    await directory.create(recursive: true);
    await _copyInto(bin, Directory(p.join(root, 'bin')));
    final libraries = await lib.exists()
        ? await _copyInto(lib, Directory(p.join(root, 'lib')), keep: library)
        : 0;
    // A service without its library fails only once asked to start a network.
    if (library != null && libraries == 0) {
      throw FileSystemException('No service library to stage', lib.path);
    }
  } finally {
    if (previous != null) _umask(previous);
  }
  return p.join(root, 'bin', p.basename(executable));
}

/// Removes the copy [stageBundle] made at [root], if there is one.
Future<void> removeBundle(String root) async {
  final directory = Directory(root);
  if (await directory.exists()) await directory.delete(recursive: true);
}

int _umask(int mask) => DynamicLibrary.process()
    .lookupFunction<Uint32 Function(Uint32), int Function(int)>('umask')(mask);

/// Copies every file of [source] into [target], keeping the layout; with
/// [keep], only the top-level entries whose names it accepts. Answers how many
/// files it copied.
Future<int> _copyInto(
  Directory source,
  Directory target, {
  bool Function(String name)? keep,
}) async {
  await target.create(recursive: true);
  var copied = 0;
  await for (final entry in source.list(recursive: true)) {
    final relative = p.relative(entry.path, from: source.path);
    if (keep != null && !keep(p.split(relative).first)) continue;
    final destination = p.join(target.path, relative);
    if (entry is Directory) {
      await Directory(destination).create(recursive: true);
    } else if (entry is File) {
      await entry.copy(destination);
      copied++;
    }
  }
  return copied;
}
