import 'dart:io';

/// Creates disposable OpenSSH Ed25519 keys for tests that need to parse keys.
///
/// Requires `ssh-keygen` (OpenSSH) to be available on PATH. The generated
/// private keys are stored only in the system temporary directory.
class SshTestKeyGenerator {
  static const passphrase = '123456';

  static Future<SshTestKeyFiles> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-ssh-test-keys-',
    );
    final unencryptedPath =
        '${directory.path}${Platform.pathSeparator}unencrypted';
    final encryptedPath = '${directory.path}${Platform.pathSeparator}encrypted';

    try {
      await _generate(unencryptedPath, '');
      await _generate(encryptedPath, passphrase);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }

    return SshTestKeyFiles._(directory, unencryptedPath, encryptedPath);
  }

  static Future<void> _generate(String path, String passphrase) async {
    final result = await Process.run('ssh-keygen', [
      '-q',
      '-t',
      'ed25519',
      '-N',
      passphrase,
      '-C',
      'terminal-master-test-only',
      '-f',
      path,
    ]);

    if (result.exitCode != 0) {
      throw StateError(
        'ssh-keygen failed to create a temporary test key: '
        '${result.stderr}',
      );
    }
  }
}

class SshTestKeyFiles {
  const SshTestKeyFiles._(
    this.directory,
    this.unencryptedPath,
    this.encryptedPath,
  );

  final Directory directory;
  final String unencryptedPath;
  final String encryptedPath;

  Future<void> dispose() => directory.delete(recursive: true);
}
