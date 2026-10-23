import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../models/ssh_connection_profile.dart';
import 'ssh_authentication.dart';
import 'ssh_credential_store.dart';

/// Why an encrypted SSH backup could not be written or read.
///
/// A code, not a sentence: parts of this run inside an isolate and none of it
/// has a `BuildContext`, so the UI renders the reason in the active language.
enum SshBackupFailure {
  invalidAuthenticationInBackup,
  invalidDataInBackup,
  selectAtLeastOneConnection,
  tooManyConnectionsSelected,
  backupPasswordTooShort,
  credentialsNotStored,
  fileTooLarge,
  backupPasswordMissing,
  invalidBackupParameters,
  invalidBackupCryptoData,
  invalidBackupContent,
  invalidConnectionCount,
  invalidConnections,
  wrongPasswordOrTampered,
  connectionNotExportable,
  profileReplacedTwice,
  profileToReplaceNotFound,
  profilesChangedDuringImport,
  importFailedWithCleanup,
  unknownBackupFormat,
}

class SshBackupException implements Exception {
  final SshBackupFailure failure;

  /// The profile name the failure refers to, when it has one.
  final String? profileName;

  /// Secondary context — the nested error for [SshBackupFailure
  /// .importFailedWithCleanup].
  final String? detail;

  const SshBackupException(this.failure, [this.profileName, this.detail]);

  /// Developer-facing English description; the UI renders the localized form.
  String get message => switch (failure) {
    SshBackupFailure.invalidAuthenticationInBackup =>
      'The SSH backup contains an invalid authentication type.',
    SshBackupFailure.invalidDataInBackup =>
      'The SSH backup contains invalid data.',
    SshBackupFailure.selectAtLeastOneConnection =>
      'Select at least one SSH connection.',
    SshBackupFailure.tooManyConnectionsSelected =>
      'Too many SSH connections selected.',
    SshBackupFailure.backupPasswordTooShort =>
      'The backup password must be at least 12 characters long.',
    SshBackupFailure.credentialsNotStored =>
      'The required credentials for "$profileName" are not stored.',
    SshBackupFailure.fileTooLarge => 'The backup file is too large.',
    SshBackupFailure.backupPasswordMissing => 'The backup password is missing.',
    SshBackupFailure.invalidBackupParameters => 'Invalid backup parameters.',
    SshBackupFailure.invalidBackupCryptoData =>
      'Invalid backup cryptographic data.',
    SshBackupFailure.invalidBackupContent => 'Invalid backup content.',
    SshBackupFailure.invalidConnectionCount =>
      'The backup contains an invalid number of connections.',
    SshBackupFailure.invalidConnections =>
      'The backup contains invalid connections.',
    SshBackupFailure.wrongPasswordOrTampered =>
      'The backup password is wrong or the file was modified.',
    SshBackupFailure.connectionNotExportable =>
      'An SSH connection contains data that cannot be exported.',
    SshBackupFailure.profileReplacedTwice =>
      'The profile "$profileName" cannot be replaced more than once.',
    SshBackupFailure.profileToReplaceNotFound =>
      'An SSH profile to be replaced was not found.',
    SshBackupFailure.profilesChangedDuringImport =>
      'The SSH profiles changed during the import. Start the import again.',
    SshBackupFailure.unknownBackupFormat => 'Unknown SSH backup format.',
    SshBackupFailure.importFailedWithCleanup =>
      '$profileName\nTemporary keychain entries could not be removed '
          'either: $detail',
  };

  @override
  String toString() => message;
}

class SshBackupEntry {
  final String name;
  final String host;
  final int port;
  final String username;
  final SshAuthenticationType authenticationType;
  final String? privateKeyPath;
  final String? password;
  final String? hostKeyType;
  final String? hostKeyFingerprint;

  const SshBackupEntry({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.authenticationType = SshAuthenticationType.password,
    this.privateKeyPath,
    this.password,
    this.hostKeyType,
    this.hostKeyFingerprint,
  });

  String get endpoint => '$username@$host:$port';

  Map<String, Object?> toJson() => {
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'authenticationType': authenticationType.name,
    if (privateKeyPath case final value?) 'privateKeyPath': value,
    if (password case final value?) 'password': value,
    if (hostKeyType case final value?) 'hostKeyType': value,
    if (hostKeyFingerprint case final value?) 'hostKeyFingerprint': value,
  };

  factory SshBackupEntry.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final host = json['host'];
    final port = json['port'];
    final username = json['username'];
    final password = json['password'];
    final authenticationTypeValue = json['authenticationType'];
    final privateKeyPath = json['privateKeyPath'];
    final authenticationType = switch (authenticationTypeValue) {
      null || 'password' => SshAuthenticationType.password,
      'privateKey' => SshAuthenticationType.privateKey,
      _ => throw const SshBackupException(
        SshBackupFailure.invalidAuthenticationInBackup,
      ),
    };
    final hostKeyType = json['hostKeyType'];
    final hostKeyFingerprint = json['hostKeyFingerprint'];
    if (name is! String ||
        name.trim().isEmpty ||
        host is! String ||
        host.trim().isEmpty ||
        port is! int ||
        port < 1 ||
        port > 65535 ||
        username is! String ||
        username.trim().isEmpty ||
        (password != null && password is! String) ||
        (authenticationType == SshAuthenticationType.password &&
            (password is! String || password.isEmpty)) ||
        (privateKeyPath != null && privateKeyPath is! String) ||
        (authenticationType == SshAuthenticationType.privateKey &&
            (privateKeyPath is! String || privateKeyPath.trim().isEmpty)) ||
        (authenticationType == SshAuthenticationType.password &&
            privateKeyPath != null) ||
        (hostKeyType != null && hostKeyType is! String) ||
        (hostKeyFingerprint != null && hostKeyFingerprint is! String)) {
      throw const SshBackupException(SshBackupFailure.invalidDataInBackup);
    }
    return SshBackupService._validatedEntry(
      SshBackupEntry(
        name: name.trim(),
        host: host.trim(),
        port: port,
        username: username.trim(),
        authenticationType: authenticationType,
        privateKeyPath: privateKeyPath is String ? privateKeyPath.trim() : null,
        password: password as String?,
        hostKeyType: hostKeyType as String?,
        hostKeyFingerprint: hostKeyFingerprint as String?,
      ),
    );
  }
}

class SshBackupService {
  static const fileExtension = 'tmsshbackup';
  static const _format = 'terminal-master-ssh-backup';
  static const _payloadFormat = 'terminal-master-ssh-backup-payload';
  static const _legacyVersion = 1;
  static const _version = 2;
  static const _iterations = 3;
  static const _memoryKiB = 65536;
  static const _parallelism = 1;
  static const _maximumEntries = 500;
  static const maximumFileBytes = 10 * 1024 * 1024;

  final SshCredentialStore credentialStore;

  const SshBackupService({required this.credentialStore});

  Future<String> exportEncrypted(
    List<SshConnectionProfile> profiles,
    String backupPassword,
  ) async {
    if (profiles.isEmpty) {
      throw const SshBackupException(
        SshBackupFailure.selectAtLeastOneConnection,
      );
    }
    if (profiles.length > _maximumEntries) {
      throw const SshBackupException(
        SshBackupFailure.tooManyConnectionsSelected,
      );
    }
    if (backupPassword.length < 12) {
      throw const SshBackupException(SshBackupFailure.backupPasswordTooShort);
    }
    final entries = <SshBackupEntry>[];
    for (final profile in profiles) {
      String? password;
      final needsSecret =
          profile.authenticationType == SshAuthenticationType.password ||
          profile.authenticationType == SshAuthenticationType.privateKey &&
              await const SshPrivateKeyLoader().isEncrypted(
                profile.privateKeyPath!,
              );
      if (needsSecret) {
        password = await credentialStore.readPassword(profile.credentialId);
      }
      if (needsSecret && (password == null || password.isEmpty)) {
        throw SshBackupException(
          SshBackupFailure.credentialsNotStored,
          profile.name,
        );
      }
      entries.add(
        _validatedEntry(
          SshBackupEntry(
            name: profile.name,
            host: profile.host,
            port: profile.port,
            username: profile.username,
            authenticationType: profile.authenticationType,
            privateKeyPath: profile.privateKeyPath,
            password: password,
            hostKeyType: profile.hostKeyType,
            hostKeyFingerprint: profile.hostKeyFingerprint,
          ),
        ),
      );
    }
    return Isolate.run(() => _encrypt(entries, backupPassword));
  }

  Future<List<SshBackupEntry>> decrypt(String backup, String backupPassword) {
    if (backup.length > maximumFileBytes) {
      throw const SshBackupException(SshBackupFailure.fileTooLarge);
    }
    if (backupPassword.isEmpty) {
      throw const SshBackupException(SshBackupFailure.backupPasswordMissing);
    }
    return Isolate.run(() => _decrypt(backup, backupPassword));
  }

  static String _encrypt(List<SshBackupEntry> entries, String backupPassword) {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final saltText = base64Encode(salt);
    final nonceText = base64Encode(nonce);
    final aad = _associatedData(_version, saltText, nonceText);
    final key = _deriveKey(backupPassword, salt);
    final plaintext = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': _payloadFormat,
          'version': _version,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'connections': entries.map((entry) => entry.toJson()).toList(),
        }),
      ),
    );
    try {
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
      return const JsonEncoder.withIndent('  ').convert({
        'format': _format,
        'version': _version,
        'kdf': {
          'name': 'argon2id',
          'salt': saltText,
          'iterations': _iterations,
          'memoryKiB': _memoryKiB,
          'parallelism': _parallelism,
        },
        'cipher': {
          'name': 'aes-256-gcm',
          'nonce': nonceText,
          'ciphertext': base64Encode(ciphertext),
        },
      });
    } finally {
      key.fillRange(0, key.length, 0);
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  static List<SshBackupEntry> _decrypt(String backup, String backupPassword) {
    try {
      final envelope = jsonDecode(backup);
      final envelopeVersion = envelope is Map<String, Object?>
          ? envelope['version']
          : null;
      if (envelope is! Map<String, Object?> ||
          envelope['format'] != _format ||
          (envelopeVersion != _legacyVersion && envelopeVersion != _version)) {
        throw const SshBackupException(SshBackupFailure.unknownBackupFormat);
      }
      final kdf = envelope['kdf'];
      final cipherData = envelope['cipher'];
      if (kdf is! Map ||
          kdf['name'] != 'argon2id' ||
          kdf['iterations'] != _iterations ||
          kdf['memoryKiB'] != _memoryKiB ||
          kdf['parallelism'] != _parallelism ||
          kdf['salt'] is! String ||
          cipherData is! Map ||
          cipherData['name'] != 'aes-256-gcm' ||
          cipherData['nonce'] is! String ||
          cipherData['ciphertext'] is! String) {
        throw const SshBackupException(
          SshBackupFailure.invalidBackupParameters,
        );
      }
      final saltText = kdf['salt'] as String;
      final nonceText = cipherData['nonce'] as String;
      final salt = Uint8List.fromList(base64Decode(saltText));
      final nonce = Uint8List.fromList(base64Decode(nonceText));
      final ciphertext = Uint8List.fromList(
        base64Decode(cipherData['ciphertext'] as String),
      );
      if (salt.length != 16 || nonce.length != 12 || ciphertext.length < 16) {
        throw const SshBackupException(
          SshBackupFailure.invalidBackupCryptoData,
        );
      }
      final key = _deriveKey(backupPassword, salt);
      Uint8List plaintext;
      try {
        final cipher = GCMBlockCipher(AESEngine())
          ..init(
            false,
            AEADParameters(
              KeyParameter(key),
              128,
              nonce,
              Uint8List.fromList(
                utf8.encode(
                  _associatedData(envelopeVersion as int, saltText, nonceText),
                ),
              ),
            ),
          );
        plaintext = cipher.process(ciphertext);
      } finally {
        key.fillRange(0, key.length, 0);
      }
      try {
        final payload = jsonDecode(utf8.decode(plaintext));
        if (payload is! Map<String, Object?> ||
            payload['format'] != _payloadFormat ||
            payload['version'] != envelopeVersion ||
            payload['connections'] is! List) {
          throw const SshBackupException(SshBackupFailure.invalidBackupContent);
        }
        final rawConnections = payload['connections'] as List;
        if (rawConnections.isEmpty || rawConnections.length > _maximumEntries) {
          throw const SshBackupException(
            SshBackupFailure.invalidConnectionCount,
          );
        }
        return List.unmodifiable(
          rawConnections.map((value) {
            if (value is! Map) {
              throw const SshBackupException(
                SshBackupFailure.invalidConnections,
              );
            }
            return SshBackupEntry.fromJson(
              value.map((key, value) => MapEntry(key.toString(), value)),
            );
          }),
        );
      } finally {
        plaintext.fillRange(0, plaintext.length, 0);
      }
    } on SshBackupException {
      rethrow;
    } on Object {
      throw const SshBackupException(SshBackupFailure.wrongPasswordOrTampered);
    }
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    try {
      final generator = Argon2BytesGenerator()
        ..init(
          Argon2Parameters(
            Argon2Parameters.ARGON2_id,
            salt,
            desiredKeyLength: 32,
            iterations: _iterations,
            memory: _memoryKiB,
            lanes: _parallelism,
            version: Argon2Parameters.ARGON2_VERSION_13,
          ),
        );
      return generator.process(passwordBytes);
    } finally {
      passwordBytes.fillRange(0, passwordBytes.length, 0);
    }
  }

  static String _associatedData(int version, String salt, String nonce) =>
      '$_format|$version|argon2id|$_iterations|$_memoryKiB|'
      '$_parallelism|aes-256-gcm|$salt|$nonce';

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static SshBackupEntry _validatedEntry(SshBackupEntry entry) {
    if (_invalidText(entry.name, 256) ||
        _invalidText(entry.host, 1024) ||
        _invalidText(entry.username, 256) ||
        (entry.password?.length ?? 0) > 65536 ||
        (entry.authenticationType == SshAuthenticationType.password &&
            (entry.password == null || entry.password!.isEmpty)) ||
        (entry.authenticationType == SshAuthenticationType.password &&
            entry.privateKeyPath != null) ||
        (entry.authenticationType == SshAuthenticationType.privateKey &&
            (entry.privateKeyPath == null ||
                entry.privateKeyPath!.trim().isEmpty ||
                _invalidText(entry.privateKeyPath!, 4096))) ||
        ((entry.hostKeyType == null) != (entry.hostKeyFingerprint == null)) ||
        (entry.hostKeyType != null &&
            (entry.hostKeyType!.trim().isEmpty ||
                _invalidText(entry.hostKeyType!, 256))) ||
        (entry.hostKeyFingerprint != null &&
            (_invalidText(entry.hostKeyFingerprint!, 2048) ||
                !_sha256Fingerprint.hasMatch(entry.hostKeyFingerprint!)))) {
      throw const SshBackupException(SshBackupFailure.connectionNotExportable);
    }
    return entry;
  }

  static bool _invalidText(String value, int maximumLength) =>
      value.length > maximumLength ||
      value.runes.any((rune) => rune < 0x20 || rune == 0x7f);

  static final _sha256Fingerprint = RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$');
}
