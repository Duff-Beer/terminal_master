import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/ssh_connection_profile.dart';

abstract interface class SshConnectionProfileStore {
  Future<List<SshConnectionProfile>> load();

  Future<SshConnectionProfile?> find(String id);

  Future<void> upsert(SshConnectionProfile profile);

  Future<void> delete(String id);

  Future<bool> trustHostKey({
    required String id,
    required String expectedHost,
    required int expectedPort,
    required String keyType,
    required String fingerprint,
  });
}

class MemorySshConnectionProfileStore implements SshConnectionProfileStore {
  final List<SshConnectionProfile> _profiles;

  MemorySshConnectionProfileStore([
    List<SshConnectionProfile> profiles = const [],
  ]) : _profiles = List.of(profiles);

  @override
  Future<List<SshConnectionProfile>> load() async =>
      List.unmodifiable(_profiles);

  @override
  Future<SshConnectionProfile?> find(String id) async {
    for (final profile in _profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  @override
  Future<void> upsert(SshConnectionProfile profile) async {
    final index = _profiles.indexWhere(
      (candidate) => candidate.id == profile.id,
    );
    if (index < 0) {
      _profiles.add(profile);
    } else {
      _profiles[index] = profile;
    }
  }

  @override
  Future<void> delete(String id) async {
    _profiles.removeWhere((profile) => profile.id == id);
  }

  @override
  Future<bool> trustHostKey({
    required String id,
    required String expectedHost,
    required int expectedPort,
    required String keyType,
    required String fingerprint,
  }) async {
    final index = _profiles.indexWhere((profile) => profile.id == id);
    if (index < 0 ||
        _profiles[index].host != expectedHost ||
        _profiles[index].port != expectedPort) {
      return false;
    }
    final current = _profiles[index];
    if (current.hostKeyFingerprint != null) {
      return current.hostKeyType == keyType &&
          current.hostKeyFingerprint == fingerprint;
    }
    _profiles[index] = _profiles[index].copyWith(
      hostKeyType: keyType,
      hostKeyFingerprint: fingerprint,
    );
    return true;
  }
}

class FileSshConnectionProfileStore implements SshConnectionProfileStore {
  static const fileName = 'ssh_connection_profiles.json';
  static const _version = 1;
  static final Map<String, Future<void>> _sharedOperations = {};

  final Directory directory;

  FileSshConnectionProfileStore(this.directory);

  File get _file => File('${directory.path}${Platform.pathSeparator}$fileName');

  @override
  Future<List<SshConnectionProfile>> load() {
    final result = Completer<List<SshConnectionProfile>>();
    _schedule(() async {
      try {
        result.complete(await _withFileLock(_load));
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<List<SshConnectionProfile>> _load() async {
    final file = _file;
    final backup = File('${file.path}.bak');
    final temporary = File('${file.path}.tmp');
    if (!await file.exists()) {
      if (await backup.exists()) {
        await backup.rename(file.path);
      } else if (await temporary.exists()) {
        await temporary.rename(file.path);
      } else {
        return const [];
      }
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?> || decoded['version'] != _version) {
      throw const FormatException('Unbekanntes SSH-Profilformat.');
    }
    final profiles = <SshConnectionProfile>[];
    final ids = <String>{};
    for (final value in (decoded['profiles'] as List<Object?>? ?? const [])) {
      if (value is! Map<String, Object?>) {
        throw const FormatException('Ungültige SSH-Profilliste.');
      }
      final profile = SshConnectionProfile.fromJson(value);
      if (!ids.add(profile.id)) {
        throw FormatException('Doppelte SSH-Profil-ID: ${profile.id}');
      }
      profiles.add(profile);
    }
    profiles.sort((left, right) => left.name.compareTo(right.name));
    return List.unmodifiable(profiles);
  }

  @override
  Future<SshConnectionProfile?> find(String id) async {
    for (final profile in await load()) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  @override
  Future<void> upsert(SshConnectionProfile profile) => _mutate((profiles) {
    final index = profiles.indexWhere(
      (candidate) => candidate.id == profile.id,
    );
    if (index < 0) {
      profiles.add(profile);
    } else {
      profiles[index] = profile;
    }
  });

  @override
  Future<void> delete(String id) => _mutate(
    (profiles) => profiles.removeWhere((profile) => profile.id == id),
  );

  @override
  Future<bool> trustHostKey({
    required String id,
    required String expectedHost,
    required int expectedPort,
    required String keyType,
    required String fingerprint,
  }) {
    final result = Completer<bool>();
    _schedule(() async {
      try {
        await _withFileLock(() async {
          final profiles = List<SshConnectionProfile>.of(await _load());
          final index = profiles.indexWhere((profile) => profile.id == id);
          if (index < 0 ||
              profiles[index].host != expectedHost ||
              profiles[index].port != expectedPort) {
            result.complete(false);
            return;
          }
          final current = profiles[index];
          if (current.hostKeyFingerprint != null) {
            result.complete(
              current.hostKeyType == keyType &&
                  current.hostKeyFingerprint == fingerprint,
            );
            return;
          }
          profiles[index] = profiles[index].copyWith(
            hostKeyType: keyType,
            hostKeyFingerprint: fingerprint,
          );
          await _write(profiles);
          result.complete(true);
        });
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<void> _mutate(void Function(List<SshConnectionProfile>) change) {
    final result = Completer<void>();
    _schedule(() async {
      try {
        await _withFileLock(() async {
          final profiles = List<SshConnectionProfile>.of(await _load());
          change(profiles);
          profiles.sort((left, right) => left.name.compareTo(right.name));
          await _write(profiles);
        });
        result.complete();
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  void _schedule(Future<void> Function() operation) {
    final path = _file.absolute.path;
    final previous = _sharedOperations[path] ?? Future.value();
    final next = previous.then((_) => operation());
    final settled = next.then<void>((_) {}, onError: (_, _) {});
    _sharedOperations[path] = settled;
    settled.whenComplete(() {
      if (identical(_sharedOperations[path], settled)) {
        _sharedOperations.remove(path);
      }
    });
  }

  Future<T> _withFileLock<T>(Future<T> Function() operation) async {
    await directory.create(recursive: true);
    final lockFile = File('${_file.path}.lock');
    final handle = await lockFile.open(mode: FileMode.append);
    await handle.lock(FileLock.exclusive);
    try {
      return await operation();
    } finally {
      await handle.unlock();
      await handle.close();
    }
  }

  Future<void> _write(List<SshConnectionProfile> profiles) async {
    await directory.create(recursive: true);
    final file = _file;
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    final content = const JsonEncoder.withIndent('  ').convert({
      'version': _version,
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
    });
    await temporary.writeAsString(content, flush: true);
    if (!await file.exists()) {
      await temporary.rename(file.path);
      return;
    }
    if (await backup.exists()) await backup.delete();
    await file.rename(backup.path);
    try {
      await temporary.rename(file.path);
      await backup.delete();
    } on Object {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }
}
