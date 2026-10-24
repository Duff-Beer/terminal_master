import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:terminal_master/models/ssh_connection_profile.dart';
import 'package:terminal_master/services/ssh_backup_service.dart';
import 'package:terminal_master/services/ssh_credential_store.dart';

import 'support/ssh_test_key_generator.dart';

void main() {
  late SshTestKeyFiles testKeys;

  setUpAll(() async {
    testKeys = await SshTestKeyGenerator.create();
  });
  tearDownAll(() => testKeys.dispose());

  test('encrypts and decrypts complete SSH connection backups', () async {
    final credentials = MemorySshCredentialStore({
      'credential-production': 'production-secret',
      'credential-test': 'test-secret',
    });
    final service = SshBackupService(credentialStore: credentials);
    const profiles = [
      SshConnectionProfile(
        id: 'production',
        name: 'Production',
        host: 'production.example.com',
        username: 'deploy',
        credentialId: 'credential-production',
        hostKeyType: 'ssh-ed25519',
        hostKeyFingerprint:
            'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      ),
      SshConnectionProfile(
        id: 'test',
        name: 'Test',
        host: '192.0.2.20',
        port: 2222,
        username: 'tester',
        credentialId: 'credential-test',
      ),
    ];

    final backup = await service.exportEncrypted(
      profiles,
      'correct horse battery staple',
    );

    expect(backup, isNot(contains('production-secret')));
    expect(backup, isNot(contains('production.example.com')));
    final envelope = jsonDecode(backup) as Map<String, Object?>;
    expect(envelope['format'], 'terminal-master-ssh-backup');
    expect(envelope['version'], 2);
    expect((envelope['kdf'] as Map)['name'], 'argon2id');
    expect((envelope['cipher'] as Map)['name'], 'aes-256-gcm');

    final entries = await service.decrypt(
      backup,
      'correct horse battery staple',
    );
    expect(entries.map((entry) => entry.endpoint), [
      'deploy@production.example.com:22',
      'tester@192.0.2.20:2222',
    ]);
    expect(entries.first.password, 'production-secret');
    expect(
      entries.first.hostKeyFingerprint,
      'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    );
  });

  test('rejects wrong passwords and modified ciphertext', () async {
    final service = SshBackupService(
      credentialStore: MemorySshCredentialStore({'credential': 'secret'}),
    );
    final backup = await service.exportEncrypted(const [
      SshConnectionProfile(
        id: 'server',
        name: 'Server',
        host: 'server.example.com',
        username: 'user',
        credentialId: 'credential',
      ),
    ], 'correct horse battery staple');

    await expectLater(
      service.decrypt(backup, 'incorrect password'),
      throwsA(isA<SshBackupException>()),
    );
    final envelope = jsonDecode(backup) as Map<String, Object?>;
    final cipher = Map<String, Object?>.from(envelope['cipher'] as Map);
    final ciphertext = cipher['ciphertext'] as String;
    cipher['ciphertext'] =
        '${ciphertext.substring(0, ciphertext.length - 2)}AA';
    envelope['cipher'] = cipher;
    await expectLater(
      service.decrypt(jsonEncode(envelope), 'correct horse battery staple'),
      throwsA(isA<SshBackupException>()),
    );
  });

  test('decrypts legacy version 1 password backups', () async {
    final service = SshBackupService(
      credentialStore: MemorySshCredentialStore(),
    );

    final entries = await service.decrypt(
      _legacyBackup('correct horse battery staple'),
      'correct horse battery staple',
    );

    expect(entries.single.name, 'Legacy server');
    expect(entries.single.authenticationType, SshAuthenticationType.password);
    expect(entries.single.password, 'legacy-password');
  });

  test('rejects incomplete pinned host-key metadata', () async {
    final service = SshBackupService(
      credentialStore: MemorySshCredentialStore({'credential': 'secret'}),
    );

    await expectLater(
      service.exportEncrypted(const [
        SshConnectionProfile(
          id: 'server',
          name: 'Server',
          host: 'server.example.com',
          username: 'user',
          credentialId: 'credential',
          hostKeyFingerprint:
              'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        ),
      ], 'correct horse battery staple'),
      throwsA(isA<SshBackupException>()),
    );
  });

  test(
    'backs up key profiles without embedding private key contents',
    () async {
      final credentials = MemorySshCredentialStore({
        'key-credential': 'key-passphrase',
      });
      final service = SshBackupService(credentialStore: credentials);
      final backup = await service.exportEncrypted([
        SshConnectionProfile(
          id: 'key-server',
          name: 'Key server',
          host: 'server.example.com',
          username: 'deploy',
          credentialId: 'key-credential',
          authenticationType: SshAuthenticationType.privateKey,
          privateKeyPath: testKeys.encryptedPath,
        ),
      ], 'correct horse battery staple');

      expect(backup, isNot(contains('key-passphrase')));
      expect(backup, isNot(contains('BEGIN OPENSSH PRIVATE KEY')));
      final entry = (await service.decrypt(
        backup,
        'correct horse battery staple',
      )).single;
      expect(entry.authenticationType, SshAuthenticationType.privateKey);
      expect(entry.privateKeyPath, testKeys.encryptedPath);
      expect(entry.password, 'key-passphrase');
    },
  );

  test('exports unencrypted keys without reading secure storage', () async {
    final service = SshBackupService(
      credentialStore: _FailingCredentialStore(),
    );

    final backup = await service.exportEncrypted([
      SshConnectionProfile(
        id: 'key-server',
        name: 'Key server',
        host: 'server.example.com',
        username: 'deploy',
        authenticationType: SshAuthenticationType.privateKey,
        privateKeyPath: testKeys.unencryptedPath,
      ),
    ], 'correct horse battery staple');

    expect(
      (await service.decrypt(
        backup,
        'correct horse battery staple',
      )).single.password,
      isNull,
    );
  });
}

class _FailingCredentialStore implements SshCredentialStore {
  @override
  Future<String?> readPassword(String profileId) =>
      Future.error(StateError('secure storage unavailable'));

  @override
  Future<void> writePassword(String profileId, String password) async {}

  @override
  Future<void> deletePassword(String profileId) async {}
}

String _legacyBackup(String password) {
  final salt = Uint8List(16);
  final nonce = Uint8List.fromList(List.filled(12, 1));
  final passwordBytes = Uint8List.fromList(utf8.encode(password));
  final generator = Argon2BytesGenerator()
    ..init(
      Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        salt,
        desiredKeyLength: 32,
        iterations: 3,
        memory: 65536,
        lanes: 1,
        version: Argon2Parameters.ARGON2_VERSION_13,
      ),
    );
  final key = generator.process(passwordBytes);
  final saltText = base64Encode(salt);
  final nonceText = base64Encode(nonce);
  final plaintext = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': 'terminal-master-ssh-backup-payload',
        'version': 1,
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'connections': [
          {
            'name': 'Legacy server',
            'host': 'legacy.example.com',
            'port': 22,
            'username': 'deploy',
            'password': 'legacy-password',
          },
        ],
      }),
    ),
  );
  final aad =
      'terminal-master-ssh-backup|1|argon2id|3|65536|1|aes-256-gcm|'
      '$saltText|$nonceText';
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(
        KeyParameter(key),
        128,
        nonce,
        Uint8List.fromList(utf8.encode(aad)),
      ),
    );
  final ciphertext = cipher.process(plaintext);
  return jsonEncode({
    'format': 'terminal-master-ssh-backup',
    'version': 1,
    'kdf': {
      'name': 'argon2id',
      'salt': saltText,
      'iterations': 3,
      'memoryKiB': 65536,
      'parallelism': 1,
    },
    'cipher': {
      'name': 'aes-256-gcm',
      'nonce': nonceText,
      'ciphertext': base64Encode(ciphertext),
    },
  });
}
