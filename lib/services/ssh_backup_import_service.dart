import '../models/ssh_connection_profile.dart';
import 'ssh_backup_service.dart';
import 'ssh_connection_profile_store.dart';
import 'ssh_credential_store.dart';

enum SshBackupConflictAction { skip, replace, copy }

class SshBackupImportItem {
  final SshBackupEntry entry;
  final SshConnectionProfile? existing;
  final bool duplicateInBackup;
  final SshBackupConflictAction action;

  const SshBackupImportItem({
    required this.entry,
    this.existing,
    this.duplicateInBackup = false,
    required this.action,
  });

  bool get hasConflict => existing != null || duplicateInBackup;

  SshBackupImportItem copyWith({SshBackupConflictAction? action}) =>
      SshBackupImportItem(
        entry: entry,
        existing: existing,
        duplicateInBackup: duplicateInBackup,
        action: action ?? this.action,
      );
}

/// A non-fatal problem noticed while applying an import.
///
/// Carries a code plus the raw detail so the UI can phrase it in the active
/// language; the service itself has no locale.
enum SshBackupImportWarningKind { previousPasswordNotRemoved }

class SshBackupImportWarning {
  final SshBackupImportWarningKind kind;
  final String detail;

  const SshBackupImportWarning(this.kind, this.detail);

  @override
  String toString() => switch (kind) {
    SshBackupImportWarningKind.previousPasswordNotRemoved =>
      'A previous password could not be removed: $detail',
  };
}

class SshBackupImportResult {
  final int imported;
  final int replaced;
  final int skipped;
  final List<SshBackupImportWarning> cleanupWarnings;

  const SshBackupImportResult({
    required this.imported,
    required this.replaced,
    required this.skipped,
    this.cleanupWarnings = const [],
  });
}

class SshBackupImportService {
  final SshConnectionProfileStore profileStore;
  final SshCredentialStore credentialStore;

  const SshBackupImportService({
    required this.profileStore,
    required this.credentialStore,
  });

  List<SshBackupImportItem> plan(
    List<SshBackupEntry> entries,
    List<SshConnectionProfile> existingProfiles,
  ) {
    final seenEndpoints = <String>{};
    return List.unmodifiable(
      entries.map((entry) {
        final duplicateInBackup = !seenEndpoints.add(
          _endpointKey(entry.host, entry.port, entry.username),
        );
        SshConnectionProfile? existing;
        for (final profile in existingProfiles) {
          if (_sameEndpoint(entry, profile)) {
            existing = profile;
            break;
          }
        }
        return SshBackupImportItem(
          entry: entry,
          existing: existing,
          duplicateInBackup: duplicateInBackup,
          action: existing == null && !duplicateInBackup
              ? SshBackupConflictAction.copy
              : SshBackupConflictAction.skip,
        );
      }),
    );
  }

  Future<SshBackupImportResult> apply(
    List<SshBackupImportItem> items,
    List<SshConnectionProfile> expectedProfiles,
  ) async {
    final updated = List<SshConnectionProfile>.of(expectedProfiles);
    final stagedCredentialIds = <String>[];
    final oldCredentialIds = <String>{};
    final replacedProfileIds = <String>{};
    var imported = 0;
    var replaced = 0;
    var skipped = 0;
    final timestamp = DateTime.now().microsecondsSinceEpoch;

    try {
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        if (item.action == SshBackupConflictAction.skip) {
          skipped++;
          continue;
        }
        final suffix = '$timestamp-$index';
        final credentialId = 'credential-import-$suffix';
        final existing = item.existing;
        final replace =
            item.action == SshBackupConflictAction.replace && existing != null;
        final profile = SshConnectionProfile(
          id: replace ? existing.id : 'ssh-import-$suffix',
          name: item.action == SshBackupConflictAction.copy && existing != null
              ? '${item.entry.name} (Import)'
              : item.entry.name,
          host: item.entry.host,
          port: item.entry.port,
          username: item.entry.username,
          credentialId: credentialId,
          authenticationType: item.entry.authenticationType,
          privateKeyPath: item.entry.privateKeyPath,
          hostKeyType: item.entry.hostKeyType,
          hostKeyFingerprint: item.entry.hostKeyFingerprint,
        );
        final secret = item.entry.password;
        if (secret != null && secret.isNotEmpty) {
          stagedCredentialIds.add(credentialId);
          await credentialStore.writePassword(credentialId, secret);
        }
        if (replace) {
          if (!replacedProfileIds.add(existing.id)) {
            throw SshBackupException(
              SshBackupFailure.profileReplacedTwice,
              existing.name,
            );
          }
          final profileIndex = updated.indexWhere(
            (candidate) => candidate.id == existing.id,
          );
          if (profileIndex < 0) {
            throw const SshBackupException(
              SshBackupFailure.profileToReplaceNotFound,
            );
          }
          updated[profileIndex] = profile;
          oldCredentialIds.add(existing.credentialId);
          replaced++;
        } else {
          updated.add(profile);
          imported++;
        }
      }

      final replacedAtomically = await profileStore.replaceAllIfUnchanged(
        expected: expectedProfiles,
        replacement: updated,
      );
      if (!replacedAtomically) {
        throw const SshBackupException(
          SshBackupFailure.profilesChangedDuringImport,
        );
      }
    } on Object catch (importError) {
      final cleanupErrors = <String>[];
      for (final credentialId in stagedCredentialIds) {
        try {
          await credentialStore.deletePassword(credentialId);
        } on Object catch (error) {
          cleanupErrors.add('$credentialId: $error');
        }
      }
      if (cleanupErrors.isNotEmpty) {
        throw SshBackupException(
          SshBackupFailure.importFailedWithCleanup,
          '$importError',
          cleanupErrors.join('; '),
        );
      }
      rethrow;
    }

    final warnings = <SshBackupImportWarning>[];
    for (final credentialId in oldCredentialIds) {
      if (updated.any((profile) => profile.credentialId == credentialId)) {
        continue;
      }
      try {
        await credentialStore.deletePassword(credentialId);
      } on Object catch (error) {
        warnings.add(
          SshBackupImportWarning(
            SshBackupImportWarningKind.previousPasswordNotRemoved,
            '$error',
          ),
        );
      }
    }
    return SshBackupImportResult(
      imported: imported,
      replaced: replaced,
      skipped: skipped,
      cleanupWarnings: List.unmodifiable(warnings),
    );
  }

  bool _sameEndpoint(SshBackupEntry entry, SshConnectionProfile profile) {
    return _endpointKey(entry.host, entry.port, entry.username) ==
        _endpointKey(profile.host, profile.port, profile.username);
  }

  String _endpointKey(String host, int port, String username) =>
      '${host.toLowerCase()}\u0000$port\u0000$username';
}
