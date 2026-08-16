import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/ssh_connection_profile.dart';
import 'ssh_credential_store.dart';

class SshAuthenticationException implements Exception {
  final String message;

  const SshAuthenticationException(this.message);

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
      throw const SshAuthenticationException('Die Key-Passphrase ist zu lang.');
    }
    final pem = await _readPem(path);
    try {
      final encrypted = SSHKeyPair.isEncryptedPem(pem);
      if (encrypted && (passphrase == null || passphrase.isEmpty)) {
        throw const SshAuthenticationException(
          'Der private SSH-Schlüssel benötigt eine Passphrase.',
        );
      }
      final identities = await Isolate.run(
        () => SSHKeyPair.fromPem(pem, encrypted ? passphrase : null),
      );
      if (identities.isEmpty) {
        throw const SshAuthenticationException(
          'Die Datei enthält keinen privaten SSH-Schlüssel.',
        );
      }
      return List.unmodifiable(identities);
    } on SshAuthenticationException {
      rethrow;
    } on Object {
      throw const SshAuthenticationException(
        'Der private SSH-Schlüssel oder seine Passphrase ist ungültig oder '
        'wird nicht unterstützt.',
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
        'Der private SSH-Schlüssel ist ungültig oder wird nicht unterstützt.',
      );
    }
  }

  Future<String> _readPem(String path) async {
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in File(path).openRead()) {
        if (bytes.length + chunk.length > maximumFileBytes) {
          throw const SshAuthenticationException(
            'Die private Schlüsseldatei ist zu groß.',
          );
        }
        bytes.add(chunk);
      }
    } on SshAuthenticationException {
      rethrow;
    } on Object {
      throw const SshAuthenticationException(
        'Die private Schlüsseldatei konnte nicht gelesen werden.',
      );
    }

    try {
      return utf8.decode(bytes.takeBytes());
    } on Object {
      throw const SshAuthenticationException(
        'Die private Schlüsseldatei ist keine gültige UTF-8-Textdatei.',
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
            'Für „${profile.name}“ ist kein Passwort im Schlüsselbund '
            'gespeichert.',
          );
        }
        return ResolvedSshPasswordAuthentication(secret);
      case SshAuthenticationType.privateKey:
        final path = profile.privateKeyPath;
        if (path == null || path.isEmpty) {
          throw SshAuthenticationException(
            'Für „${profile.name}“ ist keine private Schlüsseldatei '
            'konfiguriert.',
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
