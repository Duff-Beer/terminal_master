import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/ssh_connection_profile.dart';
import 'ssh_credential_store.dart';

/// Why SSH authentication could not be resolved.
///
/// A code, not a sentence: this runs far from any `BuildContext`, so the UI
/// renders the reason in the active language.
enum SshAuthenticationFailure {
  passphraseTooLong,
  passphraseRequired,
  noPrivateKeyInFile,
  invalidKeyOrPassphrase,
  invalidOrUnsupportedKey,
  keyFileTooLarge,
  keyFileUnreadable,
  keyFileNotUtf8,
  noStoredPassword,
  noPrivateKeyConfigured,
}

class SshAuthenticationException implements Exception {
  final SshAuthenticationFailure failure;

  /// The profile name the failure refers to, when it has one.
  final String? profileName;

  const SshAuthenticationException(this.failure, [this.profileName]);

  /// Developer-facing English description; the UI renders the localized form.
  String get message => switch (failure) {
    SshAuthenticationFailure.passphraseTooLong =>
      'The key passphrase is too long.',
    SshAuthenticationFailure.passphraseRequired =>
      'The private SSH key needs a passphrase.',
    SshAuthenticationFailure.noPrivateKeyInFile =>
      'The file does not contain a private SSH key.',
    SshAuthenticationFailure.invalidKeyOrPassphrase =>
      'The private SSH key or its passphrase is invalid or unsupported.',
    SshAuthenticationFailure.invalidOrUnsupportedKey =>
      'The private SSH key is invalid or unsupported.',
    SshAuthenticationFailure.keyFileTooLarge =>
      'The private key file is too large.',
    SshAuthenticationFailure.keyFileUnreadable =>
      'The private key file could not be read.',
    SshAuthenticationFailure.keyFileNotUtf8 =>
      'The private key file is not valid UTF-8 text.',
    SshAuthenticationFailure.noStoredPassword =>
      'No password is stored in the keychain for "$profileName".',
    SshAuthenticationFailure.noPrivateKeyConfigured =>
      'No private key file is configured for "$profileName".',
  };

  @override
  String toString() => message;
}

sealed class ResolvedSshAuthentication {
  const ResolvedSshAuthentication();
}

class ResolvedSshPasswordAuthentication extends ResolvedSshAuthentication {
  final String password;

  const ResolvedSshPasswordAuthentication(this.password);
}

class ResolvedSshPrivateKeyAuthentication extends ResolvedSshAuthentication {
  final List<SSHKeyPair> identities;

  const ResolvedSshPrivateKeyAuthentication(this.identities);
}

class SshPrivateKeyLoader {
  static const maximumFileBytes = 1024 * 1024;
  static const maximumPassphraseLength = 65536;

  const SshPrivateKeyLoader();

  Future<List<SSHKeyPair>> load(String path, [String? passphrase]) async {
    if ((passphrase?.length ?? 0) > maximumPassphraseLength) {
      throw const SshAuthenticationException(
        SshAuthenticationFailure.passphraseTooLong,
      );
    }
    final pem = await _readPem(path);
    try {
      final encrypted = SSHKeyPair.isEncryptedPem(pem);
      if (encrypted && (passphrase == null || passphrase.isEmpty)) {
        throw const SshAuthenticationException(
          SshAuthenticationFailure.passphraseRequired,
        );
      }
      final identities = await Isolate.run(
        () => SSHKeyPair.fromPem(pem, encrypted ? passphrase : null),
      );
      if (identities.isEmpty) {
        throw const SshAuthenticationException(
          SshAuthenticationFailure.noPrivateKeyInFile,
        );
      }
      return List.unmodifiable(identities);
    } on SshAuthenticationException {
      rethrow;
    } on Object {
      throw const SshAuthenticationException(
        SshAuthenticationFailure.invalidKeyOrPassphrase,
      );
    }
  }

  Future<bool> isEncrypted(String path) async {
    try {
      return SSHKeyPair.isEncryptedPem(await _readPem(path));
    } on SshAuthenticationException {
      rethrow;
    } on Object {
      throw const SshAuthenticationException(
        SshAuthenticationFailure.invalidOrUnsupportedKey,
      );
    }
  }

  Future<String> _readPem(String path) async {
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in File(path).openRead()) {
        if (bytes.length + chunk.length > maximumFileBytes) {
          throw const SshAuthenticationException(
            SshAuthenticationFailure.keyFileTooLarge,
          );
        }
        bytes.add(chunk);
      }
    } on SshAuthenticationException {
      rethrow;
    } on Object {
      throw const SshAuthenticationException(
        SshAuthenticationFailure.keyFileUnreadable,
      );
    }

    try {
      return utf8.decode(bytes.takeBytes());
    } on Object {
      throw const SshAuthenticationException(
        SshAuthenticationFailure.keyFileNotUtf8,
      );
    }
  }
}

class SshAuthenticationResolver {
  final SshCredentialStore credentialStore;
  final SshPrivateKeyLoader privateKeyLoader;

  const SshAuthenticationResolver({
    required this.credentialStore,
    this.privateKeyLoader = const SshPrivateKeyLoader(),
  });

  Future<ResolvedSshAuthentication> resolve(
    SshConnectionProfile profile,
  ) async {
    switch (profile.authenticationType) {
      case SshAuthenticationType.password:
        final secret = await credentialStore.readPassword(profile.credentialId);
        if (secret == null || secret.isEmpty) {
          throw SshAuthenticationException(
            SshAuthenticationFailure.noStoredPassword,
            profile.name,
          );
        }
        return ResolvedSshPasswordAuthentication(secret);
      case SshAuthenticationType.privateKey:
        final path = profile.privateKeyPath;
        if (path == null || path.isEmpty) {
          throw SshAuthenticationException(
            SshAuthenticationFailure.noPrivateKeyConfigured,
            profile.name,
          );
        }
        final encrypted = await privateKeyLoader.isEncrypted(path);
        final passphrase = encrypted
            ? await credentialStore.readPassword(profile.credentialId)
            : null;
        return ResolvedSshPrivateKeyAuthentication(
          await privateKeyLoader.load(path, passphrase),
        );
    }
  }
}
