import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// A SID in its string form, such as `S-1-5-21-…-1001`. Anything else could
/// smuggle more access into the SDDL [writeRestrictedFile] builds.
final sidPattern = RegExp(r'^S-1-\d+(-\d+)+$');

final _advapi32 = DynamicLibrary.open('advapi32.dll');

final _convertSidToStringSid = _advapi32
    .lookupFunction<
      Int32 Function(Pointer, Pointer<Pointer<Utf16>>),
      int Function(Pointer, Pointer<Pointer<Utf16>>)
    >('ConvertSidToStringSidW');

final _convertStringSecurityDescriptor = _advapi32
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Uint32, Pointer<Pointer>, Pointer<Uint32>),
      int Function(Pointer<Utf16>, int, Pointer<Pointer>, Pointer<Uint32>)
    >('ConvertStringSecurityDescriptorToSecurityDescriptorW');

const _sddlRevision1 = 1;

/// The SID of the user this process runs as, or null when it cannot be read.
String? currentUserSid() => using((arena) {
  final tokenSlot = arena<Pointer>();
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, tokenSlot).value) {
    return null;
  }
  final token = HANDLE(tokenSlot.value);
  try {
    final length = arena<Uint32>();
    GetTokenInformation(token, TokenUser, null, 0, length);
    if (length.value == 0) return null;
    final user = arena<Uint8>(length.value);
    if (!GetTokenInformation(
      token,
      TokenUser,
      user,
      length.value,
      length,
    ).value) {
      return null;
    }
    // TOKEN_USER starts with the SID pointer of its SID_AND_ATTRIBUTES.
    final sid = user.cast<Pointer>().value;
    final text = arena<Pointer<Utf16>>();
    if (_convertSidToStringSid(sid, text) == 0) return null;
    try {
      return text.value.toDartString();
    } finally {
      LocalFree(HLOCAL(text.value));
    }
  } finally {
    CloseHandle(token);
  }
});

/// Writes [contents] into a new file at [path] that SYSTEM and Administrators
/// control and only [readerSid] may read besides.
///
/// The file is created with that access, so it is never readable by others,
/// and never opened through whatever stood at [path] before.
void writeRestrictedFile(String path, String contents, String readerSid) {
  if (!sidPattern.hasMatch(readerSid)) {
    throw ArgumentError.value(readerSid, 'readerSid', 'Not a SID');
  }
  // Protected (P), so the directory's entries are not inherited.
  final sddl = 'D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;FR;;;$readerSid)';
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
  using((arena) {
    final descriptor = arena<Pointer>();
    if (_convertStringSecurityDescriptor(
          sddl.toNativeUtf16(allocator: arena),
          _sddlRevision1,
          descriptor,
          nullptr,
        ) ==
        0) {
      throw FileSystemException('Cannot build the access list', path);
    }
    try {
      final attributes = arena<SECURITY_ATTRIBUTES>();
      attributes.ref
        ..nLength = sizeOf<SECURITY_ATTRIBUTES>()
        ..lpSecurityDescriptor = descriptor.value;
      final handle = CreateFile(
        arena.pcwstr(path),
        GENERIC_WRITE,
        FILE_SHARE_NONE,
        attributes,
        CREATE_NEW,
        FILE_ATTRIBUTE_NORMAL,
        null,
      );
      if (!handle.value.isValid) {
        throw WindowsException(HRESULT_FROM_WIN32(handle.error));
      }
      try {
        final bytes = utf8.encode(contents);
        final buffer = arena<Uint8>(bytes.length);
        buffer.asTypedList(bytes.length).setAll(0, bytes);
        final written = arena<Uint32>();
        final wrote = WriteFile(
          handle.value,
          buffer,
          bytes.length,
          written,
          null,
        );
        if (!wrote.value || written.value != bytes.length) {
          throw WindowsException(HRESULT_FROM_WIN32(wrote.error));
        }
      } finally {
        CloseHandle(handle.value);
      }
    } finally {
      LocalFree(HLOCAL(descriptor.value));
    }
  });
}
