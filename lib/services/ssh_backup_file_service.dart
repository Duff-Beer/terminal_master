import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'ssh_backup_service.dart';

/// Bounded file I/O for encrypted SSH backup documents.
class SshBackupFileService {
  const SshBackupFileService();

  Future<String> read(File file) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > SshBackupService.maximumFileBytes) {
        throw const SshBackupException(SshBackupFailure.fileTooLarge);
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  Future<void> writeAtomically(String path, Uint8List bytes) async {
    final temporary = File(
      '$path.tmp-$pid-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
