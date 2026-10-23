import 'persisted_data_exception.dart';

enum SshAuthenticationType { password, privateKey }

class SshConnectionProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String credentialId;
  final SshAuthenticationType authenticationType;
  final String? privateKeyPath;
  final String? hostKeyType;
  final String? hostKeyFingerprint;

  const SshConnectionProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    String? credentialId,
    this.authenticationType = SshAuthenticationType.password,
    this.privateKeyPath,
    this.hostKeyType,
    this.hostKeyFingerprint,
  }) : credentialId = credentialId ?? id;

  String get endpoint => '$username@$host:$port';

  SshConnectionProfile copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    String? credentialId,
    SshAuthenticationType? authenticationType,
    String? privateKeyPath,
    bool clearPrivateKeyPath = false,
    String? hostKeyType,
    String? hostKeyFingerprint,
    bool clearHostKey = false,
  }) {
    return SshConnectionProfile(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      credentialId: credentialId ?? this.credentialId,
      authenticationType: authenticationType ?? this.authenticationType,
      privateKeyPath: clearPrivateKeyPath
          ? null
          : privateKeyPath ?? this.privateKeyPath,
      hostKeyType: clearHostKey ? null : hostKeyType ?? this.hostKeyType,
      hostKeyFingerprint: clearHostKey
          ? null
          : hostKeyFingerprint ?? this.hostKeyFingerprint,
    );
  }

  factory SshConnectionProfile.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final host = json['host'];
    final port = json['port'];
    final username = json['username'];
    final credentialId = json['credentialId'];
    final authenticationTypeValue = json['authenticationType'];
    final privateKeyPath = json['privateKeyPath'];
    final authenticationType = switch (authenticationTypeValue) {
      null || 'password' => SshAuthenticationType.password,
      'privateKey' => SshAuthenticationType.privateKey,
      _ => throw const PersistedDataException(
        PersistedDataProblem.invalidSshAuthentication,
      ),
    };
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        host is! String ||
        host.trim().isEmpty ||
        port is! int ||
        port < 1 ||
        port > 65535 ||
        username is! String ||
        username.trim().isEmpty ||
        (credentialId != null &&
            (credentialId is! String || credentialId.trim().isEmpty)) ||
        (privateKeyPath != null && privateKeyPath is! String) ||
        (privateKeyPath is String &&
            (privateKeyPath.length > 4096 ||
                privateKeyPath.runes.any(
                  (rune) => rune < 0x20 || rune == 0x7f,
                ))) ||
        (authenticationType == SshAuthenticationType.privateKey &&
            (privateKeyPath is! String || privateKeyPath.trim().isEmpty)) ||
        (authenticationType == SshAuthenticationType.password &&
            privateKeyPath != null)) {
      throw const PersistedDataException(
        PersistedDataProblem.invalidSshProfile,
      );
    }
    final hostKeyType = json['hostKeyType'];
    final hostKeyFingerprint = json['hostKeyFingerprint'];
    if ((hostKeyType != null && hostKeyType is! String) ||
        (hostKeyFingerprint != null && hostKeyFingerprint is! String)) {
      throw const PersistedDataException(
        PersistedDataProblem.invalidSshHostKey,
      );
    }
    return SshConnectionProfile(
      id: id.trim(),
      name: name.trim(),
      host: host.trim(),
      port: port,
      username: username.trim(),
      credentialId: credentialId is String ? credentialId.trim() : id.trim(),
      authenticationType: authenticationType,
      privateKeyPath: privateKeyPath is String ? privateKeyPath.trim() : null,
      hostKeyType: hostKeyType as String?,
      hostKeyFingerprint: hostKeyFingerprint as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'credentialId': credentialId,
    'authenticationType': authenticationType.name,
    if (privateKeyPath case final value?) 'privateKeyPath': value,
    if (hostKeyType case final value?) 'hostKeyType': value,
    if (hostKeyFingerprint case final value?) 'hostKeyFingerprint': value,
  };
}
