import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/ssh_connection_profile.dart';
import 'package:terminal_master/services/ssh_backup_import_service.dart';
import 'package:terminal_master/services/ssh_backup_service.dart';
import 'package:terminal_master/services/ssh_connection_profile_store.dart';
import 'package:terminal_master/services/ssh_credential_store.dart';

void main() {
  test(
    'previews conflicts and atomically imports replacements and copies',
    () async {
      const existing = SshConnectionProfile(
        id: 'existing',
        name: 'Old server',
        host: 'server.example.com',
        username: 'deploy',
        credentialId: 'old-credential',
        hostKeyType: 'ssh-ed25519',
        hostKeyFingerprint: 'SHA256:old',
      );
      final profileStore = MemorySshConnectionProfileStore([existing]);
      final credentials = MemorySshCredentialStore({
        'old-credential': 'old-password',
      });
      final service = SshBackupImportService(
        profileStore: profileStore,
        credentialStore: credentials,
      );
      const entries = [
        SshBackupEntry(
          name: 'Updated server',
          host: 'server.example.com',
          port: 22,
          username: 'deploy',
          password: 'new-password',
          hostKeyType: 'ssh-ed25519',
          hostKeyFingerprint: 'SHA256:new',
        ),
        SshBackupEntry(
          name: 'Additional server',
          host: 'additional.example.com',
          port: 2222,
          username: 'admin',
          password: 'additional-password',
        ),
      ];
      final expected = await profileStore.load();
      final plan = service.plan(entries, expected);
      expect(plan.first.hasConflict, isTrue);
      expect(plan.first.action, SshBackupConflictAction.skip);
      expect(plan.last.hasConflict, isFalse);

      final result = await service.apply([
        plan.first.copyWith(action: SshBackupConflictAction.replace),
        plan.last,
      ], expected);

      expect(result.replaced, 1);
      expect(result.imported, 1);
      final profiles = await profileStore.load();
      expect(profiles, hasLength(2));
      final replaced = profiles.singleWhere(
        (profile) => profile.id == 'existing',
      );
      expect(replaced.name, 'Updated server');
      expect(replaced.hostKeyFingerprint, 'SHA256:new');
      expect(
        await credentials.readPassword(replaced.credentialId),
        'new-password',
      );
      expect(await credentials.readPassword('old-credential'), isNull);
      final additional = profiles.singleWhere(
        (profile) => profile.id != 'existing',
      );
      expect(
        await credentials.readPassword(additional.credentialId),
        'additional-password',
      );
    },
  );

  test(
    'rejects concurrent profile changes and removes staged credentials',
    () async {
      const existing = SshConnectionProfile(
        id: 'existing',
        name: 'Server',
        host: 'server.example.com',
        username: 'deploy',
        credentialId: 'old-credential',
      );
      final profileStore = MemorySshConnectionProfileStore([existing]);
      final credentials = MemorySshCredentialStore({
        'old-credential': 'old-password',
      });
      final service = SshBackupImportService(
        profileStore: profileStore,
        credentialStore: credentials,
      );
      final expected = await profileStore.load();
      final plan = service.plan(const [
        SshBackupEntry(
          name: 'Imported',
          host: 'new.example.com',
          port: 22,
          username: 'user',
          password: 'imported-password',
        ),
      ], expected);
      await profileStore.upsert(
        existing.copyWith(name: 'Changed concurrently'),
      );

      await expectLater(
        service.apply(plan, expected),
        throwsA(isA<SshBackupException>()),
      );

      expect(credentials.passwords, {'old-credential': 'old-password'});
      expect(
        (await profileStore.find('existing'))!.name,
        'Changed concurrently',
      );
    },
  );

  test('marks duplicate backup endpoints as conflicts', () {
    final service = SshBackupImportService(
      profileStore: MemorySshConnectionProfileStore(),
      credentialStore: MemorySshCredentialStore(),
    );
    final plan = service.plan(const [
      SshBackupEntry(
        name: 'First',
        host: 'SERVER.example.com',
        port: 22,
        username: 'deploy',
        password: 'first-password',
      ),
      SshBackupEntry(
        name: 'Second',
        host: 'server.example.com',
        port: 22,
        username: 'deploy',
        password: 'second-password',
      ),
    ], const []);

    expect(plan.first.hasConflict, isFalse);
    expect(plan.first.action, SshBackupConflictAction.copy);
    expect(plan.last.duplicateInBackup, isTrue);
    expect(plan.last.hasConflict, isTrue);
    expect(plan.last.action, SshBackupConflictAction.skip);
  });

  test('keeps replaced credentials that another profile still uses', () async {
    const existing = SshConnectionProfile(
      id: 'existing',
      name: 'Existing',
      host: 'server.example.com',
      username: 'deploy',
      credentialId: 'shared-credential',
    );
    const sibling = SshConnectionProfile(
      id: 'sibling',
      name: 'Sibling',
      host: 'other.example.com',
      username: 'deploy',
      credentialId: 'shared-credential',
    );
    final profileStore = MemorySshConnectionProfileStore([existing, sibling]);
    final credentials = MemorySshCredentialStore({
      'shared-credential': 'shared-password',
    });
    final service = SshBackupImportService(
      profileStore: profileStore,
      credentialStore: credentials,
    );
    final expected = await profileStore.load();
    final plan = service.plan(const [
      SshBackupEntry(
        name: 'Replacement',
        host: 'server.example.com',
        port: 22,
        username: 'deploy',
        password: 'replacement-password',
      ),
    ], expected);

    await service.apply([
      plan.single.copyWith(action: SshBackupConflictAction.replace),
    ], expected);

    expect(
      await credentials.readPassword('shared-credential'),
      'shared-password',
    );
    final replacement = await profileStore.find('existing');
    expect(
      await credentials.readPassword(replacement!.credentialId),
      'replacement-password',
    );
  });

  test('cleans up a credential write that persisted before failing', () async {
    final profileStore = MemorySshConnectionProfileStore();
    final credentials = _PersistingFailingCredentialStore();
    final service = SshBackupImportService(
      profileStore: profileStore,
      credentialStore: credentials,
    );
    final plan = service.plan(const [
      SshBackupEntry(
        name: 'Server',
        host: 'server.example.com',
        port: 22,
        username: 'deploy',
        password: 'imported-password',
      ),
    ], const []);

    await expectLater(
      service.apply(plan, const []),
      throwsA(isA<StateError>()),
    );

    expect(credentials.passwords, isEmpty);
    expect(await profileStore.load(), isEmpty);
  });
}

class _PersistingFailingCredentialStore extends MemorySshCredentialStore {
  @override
  Future<void> writePassword(String profileId, String password) async {
    await super.writePassword(profileId, password);
    throw StateError('simulated secure storage failure');
  }
}
