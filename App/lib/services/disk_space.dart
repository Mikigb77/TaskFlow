import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

typedef _StatvfsC = Int32 Function(Pointer<Uint8> path, Pointer<Uint8> buffer);
typedef _StatvfsDart = int Function(Pointer<Uint8> path, Pointer<Uint8> buffer);
typedef _MallocC = Pointer<Uint8> Function(IntPtr size);
typedef _MallocDart = Pointer<Uint8> Function(int size);
typedef _FreeC = Void Function(Pointer<Uint8> pointer);
typedef _FreeDart = void Function(Pointer<Uint8> pointer);

/// The bytes free for the app on the disk that holds [path], through the C
/// library's `statvfs` (MN-6); null when it can't be known.
///
/// Read only on 64-bit Android and Linux, where `struct statvfs` starts
/// with `f_bsize`, `f_frsize`, `f_blocks`, `f_bfree` and `f_bavail`, each
/// 8 bytes, in bionic and glibc alike. Elsewhere, or on any failure: null,
/// which the recorder takes as room enough.
int? diskFreeBytes(String path) {
  if (!(Platform.isAndroid || Platform.isLinux) || sizeOf<IntPtr>() != 8) {
    return null;
  }
  try {
    final libc = Platform.isAndroid
        ? DynamicLibrary.open('libc.so')
        : DynamicLibrary.process();
    final statvfs = libc.lookupFunction<_StatvfsC, _StatvfsDart>('statvfs');
    final malloc = libc.lookupFunction<_MallocC, _MallocDart>('malloc');
    final free = libc.lookupFunction<_FreeC, _FreeDart>('free');
    final name = [...utf8.encode(path), 0];
    final pathBuffer = malloc(name.length);
    // Larger than either library's struct (112 bytes).
    const structSize = 256;
    final buffer = malloc(structSize);
    if (pathBuffer.address == 0 || buffer.address == 0) {
      if (pathBuffer.address != 0) free(pathBuffer);
      if (buffer.address != 0) free(buffer);
      return null;
    }
    try {
      pathBuffer.asTypedList(name.length).setAll(0, name);
      if (statvfs(pathBuffer, buffer) != 0) return null;
      final fields = buffer.cast<Uint64>();
      final blockSize = fields[1]; // f_frsize
      final available = fields[4]; // f_bavail
      if (blockSize <= 0 || available < 0) return null;
      return blockSize * available;
    } finally {
      free(pathBuffer);
      free(buffer);
    }
  } catch (_) {
    return null;
  }
}
