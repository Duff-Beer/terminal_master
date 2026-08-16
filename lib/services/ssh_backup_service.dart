import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../models/ssh_connection_profile.dart';
import 'ssh_credential_store.dart';

class SshBackupException implements Exception {
  final String message;

  const SshBackupException(this.message);

  @override
  String toString() => message;
}

class SshBackupEntry {
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String? hostKeyType;
  final String? hostKeyFingerprint;

  const SshBackupEntry({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.hostKeyType,
    this.hostKeyFingerprint,
  });

  String get endpoint => '$username@$host:$port';

  Map<String, Object?> toJson() => {
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    if (hostKeyType case final value?) 'hostKeyType': value,
    if (hostKeyFingerprint case final value?) 'hostKeyFingerprint': value,
  };

  factory SshBackupEntry.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final host = json['host'];
    final port = json['port'];
    final username = json['username'];
    final password = json['password'];
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
        password is! String ||
        password.isEmpty ||
        (hostKeyType != null && hostKeyType is! String) ||
        (hostKeyFingerprint != null && hostKeyFingerprint is! String)) {
      throw const SshBackupException('Das SSH-Backup enthält ungültige Daten.');
    }
    return SshBackupService._validatedEntry(
      SshBackupEntry(
        name: name.trim(),
        host: host.trim(),
        port: port,
        username: username.trim(),
        password: password,
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
  static const _version = 1;
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
        'Wähle mindestens eine SSH-Verbindung aus.',
      );
    }
    if (profiles.length > _maximumEntries) {
      throw const SshBackupException('Zu viele SSH-Verbindungen ausgewählt.');
    }
    if (backupPassword.length < 12) {
      throw const SshBackupException(
        'Das Backup-Passwort muss mindestens 12 Zeichen lang sein.',
      );
    }
    final entries = <SshBackupEntry>[];
    for (final profile in profiles) {
      final password = await credentialStore.readPassword(profile.credentialId);
      if (password == null || password.isEmpty) {
        throw SshBackupException(
          'Für „${profile.name}“ ist kein Passwort gespeichert.',
        );
      }
      entries.add(
        _validatedEntry(
          SshBackupEntry(
            name: profile.name,
            host: profile.host,
            port: profile.port,
            username: profile.username,
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
      throw const SshBackupException('Die Backup-Datei ist zu groß.');
    }
    if (backupPassword.isEmpty) {
      throw const SshBackupException('Das Backup-Passwort fehlt.');
    }
    return Isolate.run(() => _decrypt(backup, backupPassword));
  }

  static String _encrypt(List<SshBackupEntry> entries, String backupPassword) {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final saltText = base64Encode(salt);
    final nonceText = base64Encode(nonce);
    final aad = _associatedData(saltText, nonceText);
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
      if (envelope is! Map<String, Object?> ||
          envelope['format'] != _format ||
          envelope['version'] != _version) {
        throw const SshBackupException('Unbekanntes SSH-Backupformat.');
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
        throw const SshBackupException('Ungültige Backup-Parameter.');
      }
      final saltText = kdf['salt'] as String;
      final nonceText = cipherData['nonce'] as String;
      final salt = Uint8List.fromList(base64Decode(saltText));
      final nonce = Uint8List.fromList(base64Decode(nonceText));
      final ciphertext = Uint8List.fromList(
        base64Decode(cipherData['ciphertext'] as String),
      );
      if (salt.length != 16 || nonce.length != 12 || ciphertext.length < 16) {
        throw const SshBackupException('Ungültige Backup-Kryptodaten.');
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
                utf8.encode(_associatedData(saltText, nonceText)),
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
            payload['version'] != _version ||
            payload['connections'] is! List) {
          throw const SshBackupException('Ungültiger Backup-Inhalt.');
        }
        final rawConnections = payload['connections'] as List;
        if (rawConnections.isEmpty || rawConnections.length > _maximumEntries) {
          throw const SshBackupException(
            'Das Backup enthält eine ungültige Anzahl Verbindungen.',
          );
        }
        return List.unmodifiable(
          rawConnections.map((value) {
            if (value is! Map) {
              throw const SshBackupException(
                'Das Backup enthält ungültige Verbindungen.',
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
      throw const SshBackupException(
        'Das Backup-Passwort ist falsch oder die Datei wurde verändert.',
      );
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

  static String _associatedData(String salt, String nonce) =>
      '$_format|$_version|argon2id|$_iterations|$_memoryKiB|'
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
        entry.password.length > 65536 ||
        ((entry.hostKeyType == null) != (entry.hostKeyFingerprint == null)) ||
        (entry.hostKeyType != null &&
            (entry.hostKeyType!.trim().isEmpty ||
                _invalidText(entry.hostKeyType!, 256))) ||
        (entry.hostKeyFingerprint != null &&
            (_invalidText(entry.hostKeyFingerprint!, 2048) ||
                !_sha256Fingerprint.hasMatch(entry.hostKeyFingerprint!)))) {
      throw const SshBackupException(
        'Eine SSH-Verbindung enthält nicht exportierbare Daten.',
      );
    }
    return entry;
  }

  static bool _invalidText(String value, int maximumLength) =>
      value.length > maximumLength ||
      value.runes.any((rune) => rune < 0x20 || rune == 0x7f);

  static final _sha256Fingerprint = RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$');
}
