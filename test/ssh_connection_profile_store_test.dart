import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/ssh_connection_profile.dart';
import 'package:terminal_master/services/ssh_connection_profile_store.dart';
import 'package:terminal_master/services/ssh_credential_store.dart';

void main() {
  test('persists SSH metadata without writing the password', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-ssh-profiles-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FileSshConnectionProfileStore(directory);
    final credentials = MemorySshCredentialStore();
    const profile = SshConnectionProfile(
      id: 'production',
      name: 'Production',
      host: 'server.example.com',
      username: 'deploy',
    );

    await credentials.writePassword(
      profile.credentialId,
      'top-secret-password',
    );
    await store.upsert(profile);

    final loaded = (await store.load()).single;
    expect(loaded.endpoint, 'deploy@server.example.com:22');
    expect(
      await credentials.readPassword(profile.credentialId),
      'top-secret-password',
    );
    final metadata = await File(
      '${directory.path}${Platform.pathSeparator}'
      '${FileSshConnectionProfileStore.fileName}',
    ).readAsString();
    expect(metadata, isNot(contains('top-secret-password')));
  });

  test('persists key authentication without key contents', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-ssh-key-profile-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FileSshConnectionProfileStore(directory);
    const profile = SshConnectionProfile(
      id: 'key-server',
      name: 'Key server',
      host: 'server.example.com',
      username: 'deploy',
      authenticationType: SshAuthenticationType.privateKey,
      privateKeyPath: '/home/user/.ssh/id_ed25519',
    );

    await store.upsert(profile);

    final loaded = (await store.load()).single;
    expect(loaded.authenticationType, SshAuthenticationType.privateKey);
    expect(loaded.privateKeyPath, '/home/user/.ssh/id_ed25519');
    final metadata = await File(
      '${directory.path}${Platform.pathSeparator}'
      '${FileSshConnectionProfileStore.fileName}',
    ).readAsString();
    expect(metadata, isNot(contains('BEGIN OPENSSH PRIVATE KEY')));
  });

  test('loads legacy profiles as password authentication', () {
    final profile = SshConnectionProfile.fromJson({
      'id': 'legacy',
      'name': 'Legacy',
      'host': 'legacy.example.com',
      'port': 22,
      'username': 'user',
    });

    expect(profile.authenticationType, SshAuthenticationType.password);
    expect(profile.privateKeyPath, isNull);
  });

  test(
    'updates host trust and deletes profiles independently of secrets',
    () async {
      final store = MemorySshConnectionProfileStore();
      final credentials = MemorySshCredentialStore();
      const profile = SshConnectionProfile(
        id: 'test',
        name: 'Test',
        host: '192.0.2.10',
        username: 'tester',
      );
      await store.upsert(profile);
      await credentials.writePassword(profile.credentialId, 'secret');

      await store.upsert(
        profile.copyWith(
          hostKeyType: 'ssh-ed25519',
          hostKeyFingerprint: 'SHA256:trusted',
        ),
      );
      expect(
        (await store.find(profile.id))!.hostKeyFingerprint,
        'SHA256:trusted',
      );

      await credentials.deletePassword(profile.credentialId);
      await store.delete(profile.id);
      expect(await store.find(profile.id), isNull);
      expect(await credentials.readPassword(profile.credentialId), isNull);
    },
  );

  test('serializes writes from separate store instances', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-ssh-profiles-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final first = FileSshConnectionProfileStore(directory);
    final second = FileSshConnectionProfileStore(directory);

    await Future.wait([
      first.upsert(
        const SshConnectionProfile(
          id: 'first',
          name: 'First',
          host: 'first.example.com',
          username: 'user',
        ),
      ),
      second.upsert(
        const SshConnectionProfile(
          id: 'second',
          name: 'Second',
          host: 'second.example.com',
          username: 'user',
        ),
      ),
    ]);

    expect((await first.load()).map((profile) => profile.id), [
      'first',
      'second',
    ]);
  });

  test('does not replace a concurrently established host-key pin', () async {
    final store = MemorySshConnectionProfileStore([
      const SshConnectionProfile(
        id: 'server',
        name: 'Server',
        host: 'server.example.com',
        username: 'user',
      ),
    ]);

    expect(
      await store.trustHostKey(
        id: 'server',
        expectedHost: 'server.example.com',
        expectedPort: 22,
        keyType: 'ssh-ed25519',
        fingerprint: 'SHA256:first',
      ),
      isTrue,
    );
    expect(
      await store.trustHostKey(
        id: 'server',
        expectedHost: 'server.example.com',
        expectedPort: 22,
        keyType: 'ssh-ed25519',
        fingerprint: 'SHA256:second',
      ),
      isFalse,
    );
    expect((await store.find('server'))!.hostKeyFingerprint, 'SHA256:first');
  });
}
