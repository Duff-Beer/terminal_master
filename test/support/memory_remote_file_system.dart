import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:terminal_master/services/remote_file_upload.dart';

/// An in-memory remote file system whose home directory is `/home/user`.
class MemoryRemoteFileSystem implements RemoteFileSystem {
  final Map<String, List<int>> files = {};
  final Set<String> directories = {'/home/user'};
  final List<String> deleted = [];
  bool closed = false;

  @override
  Future<String> homeDirectory() async => '/home/user';

  @override
  Future<String> canonicalize(String remotePath) async {
    final normalized = path.posix.normalize(
      path.posix.isAbsolute(remotePath)
          ? remotePath
          : path.posix.join('/home/user', remotePath),
    );
    if (!directories.contains(normalized) && !files.containsKey(normalized)) {
      throw StateError('No such file: $normalized');
    }
    return normalized;
  }

  @override
  Future<List<String>> listDirectories(String remotePath) async => [
    for (final directory in directories)
      if (path.posix.dirname(directory) == remotePath &&
          directory != remotePath)
        path.posix.basename(directory),
  ]..sort();

  @override
  Future<RemoteEntryType?> entryType(String remotePath) async {
    if (directories.contains(remotePath)) return RemoteEntryType.directory;
    if (files.containsKey(remotePath)) return RemoteEntryType.file;
    return null;
  }

  @override
  Future<void> createDirectory(String remotePath) async {
    if (!directories.contains(path.posix.dirname(remotePath))) {
      throw StateError('parent of $remotePath missing');
    }
    directories.add(remotePath);
  }

  @override
  Future<void> writeFile(
    String remotePath,
    Stream<Uint8List> data, {
    void Function(int bytes)? onProgress,
  }) async {
    final bytes = <int>[];
    files[remotePath] = bytes;
    await for (final chunk in data) {
      bytes.addAll(chunk);
      onProgress?.call(bytes.length);
    }
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    deleted.add(remotePath);
    files.remove(remotePath);
  }

  @override
  Future<void> close() async => closed = true;
}
