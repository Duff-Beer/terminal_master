import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as path;

enum RemoteEntryType { file, directory, other }

/// The remote operations an upload needs, so the upload logic does not depend
/// on SFTP directly and can be tested against an in-memory fake.
abstract interface class RemoteFileSystem {
  /// The absolute path of the remote user's home directory.
  Future<String> homeDirectory();

  /// Resolves `.`, `..` and symbolic links in [remotePath]. Fails when the
  /// path does not exist.
  Future<String> canonicalize(String remotePath);

  /// Names of the subdirectories of [remotePath], sorted.
  Future<List<String>> listDirectories(String remotePath);

  /// The type of the entry at [remotePath], or null when nothing is there.
  Future<RemoteEntryType?> entryType(String remotePath);

  Future<void> createDirectory(String remotePath);

  /// Creates or truncates [remotePath] and writes [data] into it.
  /// [onProgress] receives the number of bytes of this file written so far.
  Future<void> writeFile(
    String remotePath,
    Stream<Uint8List> data, {
    void Function(int bytes)? onProgress,
  });

  Future<void> deleteFile(String remotePath);

  Future<void> close();
}

/// OSC 1337 key the SSH backend uses to report the remote shell's process ID.
const remoteShellPidOscKey = 'TerminalMasterShellPid';

/// A terminal backend that can open a file system on its remote host.
abstract interface class RemoteFileTransfer {
  Future<RemoteFileSystem> openFileSystem();

  /// The current directory of the remote process [pid], or null when the
  /// host cannot tell.
  Future<String?> workingDirectoryOfProcess(int pid);
}

class SftpRemoteFileSystem implements RemoteFileSystem {
  final SftpClient _sftp;

  SftpRemoteFileSystem(this._sftp);

  @override
  Future<String> homeDirectory() => _sftp.absolute('.');

  @override
  Future<String> canonicalize(String remotePath) => _sftp.absolute(remotePath);

  @override
  Future<List<String>> listDirectories(String remotePath) async {
    final entries = await _sftp.listdir(remotePath);
    return [
      for (final entry in entries)
        if (entry.attr.isDirectory &&
            entry.filename != '.' &&
            entry.filename != '..')
          entry.filename,
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  @override
  Future<RemoteEntryType?> entryType(String remotePath) async {
    try {
      final attributes = await _sftp.stat(remotePath);
      if (attributes.isDirectory) return RemoteEntryType.directory;
      if (attributes.isFile) return RemoteEntryType.file;
      return RemoteEntryType.other;
    } on SftpStatusError catch (error) {
      if (error.code == SftpStatusCode.noSuchFile) return null;
      rethrow;
    }
  }

  @override
  Future<void> createDirectory(String remotePath) => _sftp.mkdir(remotePath);

  @override
  Future<void> writeFile(
    String remotePath,
    Stream<Uint8List> data, {
    void Function(int bytes)? onProgress,
  }) async {
    final file = await _sftp.open(
      remotePath,
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate |
          SftpFileOpenMode.write,
    );
    // SftpFile.write() never completes when its source stream errors, so
    // cancellation would hang; writing chunk by chunk propagates errors.
    try {
      var offset = 0;
      await for (final chunk in data) {
        await file.writeBytes(chunk, offset: offset);
        offset += chunk.length;
        onProgress?.call(offset);
      }
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> deleteFile(String remotePath) => _sftp.remove(remotePath);

  @override
  Future<void> close() => _sftp.close();
}

enum UploadConflictAction { overwrite, rename, skip }

/// An existing remote entry that a dropped file or directory would replace.
class UploadConflict {
  final String remotePath;
  final bool isDirectory;

  /// False when the existing entry has a different type, e.g. a file where a
  /// directory should go; replacing it would mean deleting it first.
  final bool canOverwrite;

  const UploadConflict({
    required this.remotePath,
    required this.isDirectory,
    required this.canOverwrite,
  });
}

class UploadConflictDecision {
  final UploadConflictAction action;
  final bool applyToAll;

  const UploadConflictDecision(this.action, {this.applyToAll = false});
}

/// Asks how to handle [conflict]; returning null cancels the whole upload.
typedef UploadConflictResolver =
    Future<UploadConflictDecision?> Function(UploadConflict conflict);

class UploadProgress {
  final int transferredBytes;
  final int totalBytes;
  final String currentFile;

  const UploadProgress({
    required this.transferredBytes,
    required this.totalBytes,
    required this.currentFile,
  });

  double? get fraction =>
      totalBytes == 0 ? null : (transferredBytes / totalBytes).clamp(0, 1);
}

class UploadCancelledException implements Exception {
  const UploadCancelledException();

  @override
  String toString() => 'The upload was cancelled.';
}

/// Uploads local files and directories into a remote directory.
///
/// Directories are uploaded recursively. Symbolic links inside dropped
/// directories are skipped so a link cannot pull in files from elsewhere.
class RemoteFileUploader {
  final RemoteFileSystem fileSystem;
  final UploadConflictResolver resolveConflict;
  final void Function(UploadProgress progress)? onProgress;
  final bool Function()? isCancelled;

  UploadConflictAction? _actionForAll;
  int _transferredBytes = 0;
  int _totalBytes = 0;

  RemoteFileUploader({
    required this.fileSystem,
    required this.resolveConflict,
    this.onProgress,
    this.isCancelled,
  });

  /// Uploads [localPaths] into [remoteDirectory], or the remote home directory
  /// when it is null, and returns the remote path of each uploaded top-level
  /// entry. Skipped entries are left out of the result.
  Future<List<String>> upload(
    List<String> localPaths, {
    String? remoteDirectory,
  }) async {
    final targetDirectory = remoteDirectory ?? await fileSystem.homeDirectory();
    _totalBytes = 0;
    for (final localPath in localPaths) {
      _totalBytes += await _localSize(localPath);
    }

    final uploaded = <String>[];
    for (final localPath in localPaths) {
      final remotePath = await _uploadEntry(localPath, targetDirectory);
      if (remotePath != null) uploaded.add(remotePath);
    }
    return uploaded;
  }

  Future<String?> _uploadEntry(String localPath, String remoteDirectory) async {
    _checkCancelled();
    final isDirectory = FileSystemEntity.isDirectorySync(localPath);
    final target = await _resolveTarget(
      path.posix.join(remoteDirectory, path.basename(localPath)),
      isDirectory: isDirectory,
    );
    if (target == null) return null;

    if (isDirectory) {
      if (!target.exists) await fileSystem.createDirectory(target.path);
      final children = Directory(localPath).listSync(followLinks: false)
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final child in children) {
        if (child is Link) continue;
        await _uploadEntry(child.path, target.path);
      }
    } else {
      await _uploadFile(localPath, target.path);
    }
    return target.path;
  }

  Future<void> _uploadFile(String localPath, String remotePath) async {
    final startBytes = _transferredBytes;
    final data = File(localPath).openRead().map((chunk) {
      _checkCancelled();
      return chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    });
    _reportProgress(remotePath);
    try {
      await fileSystem.writeFile(
        remotePath,
        data,
        onProgress: (bytes) {
          _transferredBytes = startBytes + bytes;
          _reportProgress(remotePath);
        },
      );
    } on UploadCancelledException {
      // Leave no truncated file behind.
      await fileSystem.deleteFile(remotePath).catchError((_) {});
      rethrow;
    }
    _transferredBytes = startBytes + await File(localPath).length();
    _reportProgress(remotePath);
  }

  /// Picks where [remotePath] goes, asking on conflicts. Returns null when the
  /// entry should be skipped.
  Future<({String path, bool exists})?> _resolveTarget(
    String remotePath, {
    required bool isDirectory,
  }) async {
    final existing = await fileSystem.entryType(remotePath);
    if (existing == null) return (path: remotePath, exists: false);

    final canOverwrite =
        existing ==
        (isDirectory ? RemoteEntryType.directory : RemoteEntryType.file);
    var action = _actionForAll;
    if (action == null ||
        (action == UploadConflictAction.overwrite && !canOverwrite)) {
      final decision = await resolveConflict(
        UploadConflict(
          remotePath: remotePath,
          isDirectory: isDirectory,
          canOverwrite: canOverwrite,
        ),
      );
      if (decision == null) throw const UploadCancelledException();
      action = decision.action;
      if (decision.applyToAll) _actionForAll = action;
    }
    _checkCancelled();

    return switch (action) {
      // Overwriting a directory merges into it; its entries are checked again.
      UploadConflictAction.overwrite when canOverwrite => (
        path: remotePath,
        exists: true,
      ),
      UploadConflictAction.overwrite || UploadConflictAction.rename => (
        path: await _freeName(remotePath, isDirectory: isDirectory),
        exists: false,
      ),
      UploadConflictAction.skip => null,
    };
  }

  /// Returns `name (1).ext`, `name (2).ext`, ... for the first free name.
  Future<String> _freeName(
    String remotePath, {
    required bool isDirectory,
  }) async {
    final directory = path.posix.dirname(remotePath);
    final name = path.posix.basename(remotePath);
    final extension = isDirectory || name.startsWith('.')
        ? ''
        : path.posix.extension(name);
    final stem = name.substring(0, name.length - extension.length);
    for (var counter = 1; ; counter++) {
      final candidate = path.posix.join(
        directory,
        '$stem ($counter)$extension',
      );
      if (await fileSystem.entryType(candidate) == null) return candidate;
    }
  }

  Future<int> _localSize(String localPath) async {
    if (!FileSystemEntity.isDirectorySync(localPath)) {
      return File(localPath).length();
    }
    var size = 0;
    await for (final entity in Directory(
      localPath,
    ).list(recursive: true, followLinks: false)) {
      if (entity is File) size += await entity.length();
    }
    return size;
  }

  void _reportProgress(String remotePath) {
    onProgress?.call(
      UploadProgress(
        transferredBytes: _transferredBytes,
        totalBytes: _totalBytes,
        currentFile: remotePath,
      ),
    );
  }

  void _checkCancelled() {
    if (isCancelled?.call() ?? false) throw const UploadCancelledException();
  }
}
