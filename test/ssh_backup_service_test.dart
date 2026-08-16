import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/ssh_connection_profile.dart';
import 'package:terminal_master/services/ssh_backup_service.dart';
import 'package:terminal_master/services/ssh_credential_store.dart';

void main() {
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
}
