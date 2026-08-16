import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SshCredentialStore {
  Future<String?> readPassword(String profileId);

  Future<void> writePassword(String profileId, String password);

  Future<void> deletePassword(String profileId);
}

class MemorySshCredentialStore implements SshCredentialStore {
  final Map<String, String> passwords;

  MemorySshCredentialStore([Map<String, String> passwords = const {}])
    : passwords = Map.of(passwords);

  @override
  Future<String?> readPassword(String profileId) async => passwords[profileId];

  @override
  Future<void> writePassword(String profileId, String password) async {
    passwords[profileId] = password;
  }

  @override
  Future<void> deletePassword(String profileId) async {
    passwords.remove(profileId);
  }
}

class SecureSshCredentialStore implements SshCredentialStore {
  static const _prefix = 'ssh.profile.';

  final FlutterSecureStorage storage;

  const SecureSshCredentialStore({
    this.storage = const FlutterSecureStorage(
      mOptions: MacOsOptions(useDataProtectionKeyChain: false),
    ),
  });

  String _key(String profileId) => '$_prefix$profileId.password';

  @override
  Future<String?> readPassword(String profileId) =>
      storage.read(key: _key(profileId));

  @override
  Future<void> writePassword(String profileId, String password) {
    if (password.isEmpty) return deletePassword(profileId);
    return storage.write(key: _key(profileId), value: password);
  }

  @override
  Future<void> deletePassword(String profileId) =>
      storage.delete(key: _key(profileId));
}
