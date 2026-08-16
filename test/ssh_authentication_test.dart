import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/ssh_connection_profile.dart';
import 'package:terminal_master/services/ssh_authentication.dart';
import 'package:terminal_master/services/ssh_credential_store.dart';

void main() {
  test('loads an unencrypted Ed25519 private key', () async {
    final identities = await const SshPrivateKeyLoader().load(
      'test/fixtures/id_ed25519',
    );

    expect(identities, hasLength(1));
    expect(identities.single, isA<OpenSSHEd25519KeyPair>());
  });

  test('resolves key authentication without a stored passphrase', () async {
    final authentication =
        await SshAuthenticationResolver(
          credentialStore: _FailingCredentialStore(),
        ).resolve(
          const SshConnectionProfile(
            id: 'key-server',
            name: 'Key server',
            host: 'server.example.com',
            username: 'deploy',
            authenticationType: SshAuthenticationType.privateKey,
            privateKeyPath: 'test/fixtures/id_ed25519',
          ),
        );

    expect(authentication, isA<ResolvedSshPrivateKeyAuthentication>());
  });

  test('loads an encrypted key only with the correct passphrase', () async {
    await expectLater(
      const SshPrivateKeyLoader().load('test/fixtures/id_ed25519_encrypted'),
      throwsA(isA<SshAuthenticationException>()),
    );
    await expectLater(
      const SshPrivateKeyLoader().load(
        'test/fixtures/id_ed25519_encrypted',
        'wrong',
      ),
      throwsA(isA<SshAuthenticationException>()),
    );

    final identities = await const SshPrivateKeyLoader().load(
      'test/fixtures/id_ed25519_encrypted',
      '123456',
    );
    expect(identities.single, isA<OpenSSHEd25519KeyPair>());
  });

  test('rejects malformed and oversized private keys', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-key-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final malformed = File('${directory.path}/malformed')
      ..writeAsStringSync('not a private key');
    final oversized = File('${directory.path}/oversized')
      ..writeAsBytesSync(
        List.filled(SshPrivateKeyLoader.maximumFileBytes + 1, 0x41),
      );

    await expectLater(
      const SshPrivateKeyLoader().load(malformed.path),
      throwsA(isA<SshAuthenticationException>()),
    );
    await expectLater(
      const SshPrivateKeyLoader().load(oversized.path),
      throwsA(isA<SshAuthenticationException>()),
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
