import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/error_presenter.dart';
import '../models/ssh_connection_profile.dart';
import '../services/ssh_authentication.dart';
import '../services/ssh_backup_file_service.dart';
import '../services/ssh_backup_import_service.dart';
import '../services/ssh_backup_service.dart';
import '../services/ssh_connection_profile_store.dart';
import '../services/ssh_credential_store.dart';
import '../services/ssh_host_key_verifier.dart';
import '../services/ssh_terminal_backend.dart';
import '../widgets/output_dialog.dart';
import '../widgets/terminal_panel.dart';

part 'ssh_connection_dialogs.dart';

class SshConnectionsPage extends StatefulWidget {
  final SshConnectionProfileStore profileStore;
  final SshCredentialStore credentialStore;
  final SshHostKeyVerifier hostKeyVerifier;
  final Future<String?> Function()? exportPathPicker;
  final Future<String?> Function()? importPathPicker;

  const SshConnectionsPage({
    super.key,
    required this.profileStore,
    required this.credentialStore,
    required this.hostKeyVerifier,
    this.exportPathPicker,
    this.importPathPicker,
  });

  @override
  State<SshConnectionsPage> createState() => _SshConnectionsPageState();
}

class _SshConnectionsPageState extends State<SshConnectionsPage> {
  final _searchController = TextEditingController();
  List<SshConnectionProfile> _profiles = const [];
  bool _loading = true;
  String? _error;
  String? _busyProfileId;
  bool _isTransferring = false;

  List<SshConnectionProfile> get _filteredProfiles {
    final terms = _searchController.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    if (terms.isEmpty) return _profiles;
    return _profiles
        .where((profile) {
          // Deliberately bilingual and not localized: the haystack carries
          // both German and English terms so a search matches either way,
          // regardless of the active UI language.
          final authentication =
              profile.authenticationType == SshAuthenticationType.privateKey
              ? 'ssh-key key schlüssel private key'
              : 'passwort password';
          final searchable = [
            profile.name,
            profile.host,
            profile.username,
            profile.port.toString(),
            profile.endpoint,
            authentication,
          ].join(' ').toLowerCase();
          return terms.every(searchable.contains);
        })
        .toList(growable: false);
  }

  SshBackupService get _backupService =>
      SshBackupService(credentialStore: widget.credentialStore);

  SshBackupImportService get _importService => SshBackupImportService(
    profileStore: widget.profileStore,
    credentialStore: widget.credentialStore,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profiles = await widget.profileStore.load();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _error = null;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _edit([SshConnectionProfile? existing]) async {
    if (_busyProfileId != null || _isTransferring) return;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<_SshProfileInput>(
      context: context,
      builder: (context) => _SshProfileDialog(profile: existing),
    );
    if (result == null || !mounted) return;

    final endpointChanged =
        existing != null &&
        (existing.host != result.host || existing.port != result.port);
    final authenticationChanged =
        existing != null &&
        existing.authenticationType != result.authenticationType;
    final privateKeyChanged =
        result.authenticationType == SshAuthenticationType.privateKey &&
        existing?.privateKeyPath != result.privateKeyPath;
    final secretChanged = result.secret.isNotEmpty;
    final secretCleared = result.clearSecret;
    final credentialChanged =
        existing == null ||
        authenticationChanged ||
        privateKeyChanged ||
        secretChanged ||
        secretCleared;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final profileId = existing?.id ?? 'ssh-$timestamp';
    final credentialId = credentialChanged
        ? 'credential-$timestamp'
        : existing.credentialId;
    final profile = SshConnectionProfile(
      id: profileId,
      name: result.name,
      host: result.host,
      port: result.port,
      username: result.username,
      credentialId: credentialId,
      authenticationType: result.authenticationType,
      privateKeyPath: result.privateKeyPath,
      hostKeyType: endpointChanged ? null : existing?.hostKeyType,
      hostKeyFingerprint: endpointChanged ? null : existing?.hostKeyFingerprint,
    );
    setState(() => _busyProfileId = profile.id);
    var stagedCredential = false;
    var profilesCommitted = false;
    try {
      final expectedProfiles = await widget.profileStore.load();
      if (existing != null) {
        SshConnectionProfile? current;
        for (final candidate in expectedProfiles) {
          if (candidate.id == existing.id) {
            current = candidate;
            break;
          }
        }
        if (current == null ||
            jsonEncode(current.toJson()) != jsonEncode(existing.toJson())) {
          throw StateError(l10n.sshProfileChangedReopen);
        }
      }
      final oldCredentialId = existing?.credentialId;
      final oldSecret = oldCredentialId == null
          ? null
          : await widget.credentialStore.readPassword(oldCredentialId);
      final canRetainSecret =
          existing != null && !authenticationChanged && !secretCleared;
      final newSecret = secretCleared
          ? ''
          : result.secret.isNotEmpty
          ? result.secret
          : canRetainSecret
          ? oldSecret ?? ''
          : '';
      if (profile.authenticationType == SshAuthenticationType.password &&
          newSecret.isEmpty) {
        throw StateError(l10n.sshPasswordRequired);
      }
      if (profile.authenticationType == SshAuthenticationType.privateKey) {
        await const SshPrivateKeyLoader().load(
          profile.privateKeyPath!,
          newSecret,
        );
      }
      if (credentialChanged && newSecret.isNotEmpty) {
        stagedCredential = true;
        await widget.credentialStore.writePassword(
          profile.credentialId,
          newSecret,
        );
      }
      final replacement = List<SshConnectionProfile>.of(expectedProfiles);
      final profileIndex = replacement.indexWhere(
        (candidate) => candidate.id == profile.id,
      );
      if (profileIndex < 0) {
        replacement.add(profile);
      } else {
        replacement[profileIndex] = profile;
      }
      profilesCommitted = await widget.profileStore.replaceAllIfUnchanged(
        expected: expectedProfiles,
        replacement: replacement,
      );
      if (!profilesCommitted) {
        throw StateError(l10n.sshProfilesChangedRetry);
      }
      Object? cleanupError;
      if (credentialChanged &&
          oldCredentialId != null &&
          oldCredentialId != profile.credentialId &&
          !replacement.any(
            (candidate) => candidate.credentialId == oldCredentialId,
          )) {
        try {
          await widget.credentialStore.deletePassword(oldCredentialId);
        } on Object catch (error) {
          cleanupError = error;
        }
      }
      await _load();
      if (cleanupError != null && mounted) {
        showOutputDialog(
          context,
          l10n.sshSavedButCredentialCleanupFailed(
            localizeError(l10n, cleanupError),
          ),
        );
      }
    } on Object catch (error) {
      if (stagedCredential && !profilesCommitted) {
        try {
          await widget.credentialStore.deletePassword(profile.credentialId);
        } on Object catch (cleanupError) {
          if (mounted) {
            showOutputDialog(
              context,
              l10n.sshSaveFailedWithCleanup(
                localizeError(l10n, error),
                localizeError(l10n, cleanupError),
              ),
            );
          }
          return;
        }
      }
      if (mounted) {
        showOutputDialog(
          context,
          l10n.sshSaveFailed(localizeError(l10n, error)),
        );
      }
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _delete(SshConnectionProfile profile) async {
    if (_busyProfileId != null || _isTransferring) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sshDeleteTitle),
        content: Text(l10n.sshDeleteMessage(profile.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-delete-ssh-profile'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyProfileId = profile.id);
    try {
      final expectedProfiles = await widget.profileStore.load();
      SshConnectionProfile? current;
      for (final candidate in expectedProfiles) {
        if (candidate.id == profile.id) {
          current = candidate;
          break;
        }
      }
      if (current == null ||
          jsonEncode(current.toJson()) != jsonEncode(profile.toJson())) {
        throw StateError(l10n.sshProfileChangedDeleteAgain);
      }
      final remainingProfiles = expectedProfiles
          .where((candidate) => candidate.id != profile.id)
          .toList(growable: false);
      final deleted = await widget.profileStore.replaceAllIfUnchanged(
        expected: expectedProfiles,
        replacement: remainingProfiles,
      );
      if (!deleted) {
        throw StateError(l10n.sshProfilesChangedRetry);
      }
      Object? cleanupError;
      if (!remainingProfiles.any(
        (candidate) => candidate.credentialId == profile.credentialId,
      )) {
        try {
          await widget.credentialStore.deletePassword(profile.credentialId);
        } on Object catch (error) {
          cleanupError = error;
        }
      }
      await _load();
      if (cleanupError != null && mounted) {
        showOutputDialog(
          context,
          l10n.sshDeletedButCredentialCleanupFailed(
            localizeError(l10n, cleanupError),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showOutputDialog(
          context,
          l10n.sshDeleteFailed(localizeError(l10n, error)),
        );
      }
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _test(SshConnectionProfile profile) async {
    if (_busyProfileId != null || _isTransferring) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busyProfileId = profile.id);
    try {
      final authentication = await SshAuthenticationResolver(
        credentialStore: widget.credentialStore,
      ).resolve(profile);
      final backend = await SshTerminalBackend.connect(
        profile: profile,
        authentication: authentication,
        hostKeyVerifier: widget.hostKeyVerifier,
        rows: 24,
        columns: 80,
      );
      backend.kill();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.sshConnectionSucceeded)));
      }
    } on Object catch (error) {
      if (mounted) {
        showOutputDialog(
          context,
          l10n.sshConnectionFailed(localizeError(l10n, error)),
        );
      }
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _connect(SshConnectionProfile profile) async {
    if (_busyProfileId != null || _isTransferring) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busyProfileId = profile.id);
    try {
      await SshAuthenticationResolver(
        credentialStore: widget.credentialStore,
      ).resolve(profile);
      if (!mounted) return;
      final controller = TerminalPanelScope.of(context);
      await controller.createSshTab(profile);
      await _load();
      if (mounted) ConfigurationPanelScope.maybeOf(context)?.close();
    } on Object catch (error) {
      if (mounted) {
        showOutputDialog(
          context,
          l10n.sshConnectionFailed(localizeError(l10n, error)),
        );
      }
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _exportBackup() async {
    if (_profiles.isEmpty || _isTransferring || _busyProfileId != null) return;
    final l10n = AppLocalizations.of(context);
    final request = await showDialog<_SshBackupExportRequest>(
      context: context,
      builder: (context) => _SshBackupExportDialog(profiles: _profiles),
    );
    if (request == null || !mounted) return;

    setState(() => _isTransferring = true);
    Uint8List? backupBytes;
    try {
      final selected = _profiles
          .where((profile) => request.profileIds.contains(profile.id))
          .toList(growable: false);
      final backup = await _backupService.exportEncrypted(
        selected,
        request.password,
      );
      backupBytes = Uint8List.fromList(utf8.encode(backup));
      final pickerWritesFile =
          widget.exportPathPicker == null &&
          (Platform.isAndroid || Platform.isIOS);
      final path =
          await (widget.exportPathPicker?.call() ??
              FilePicker.platform.saveFile(
                dialogTitle: l10n.sshExportDialogTitle,
                fileName:
                    'terminal-master-ssh.${SshBackupService.fileExtension}',
                type: FileType.custom,
                allowedExtensions: const [SshBackupService.fileExtension],
                bytes: pickerWritesFile ? backupBytes : null,
              ));
      if (path == null || !mounted) return;
      final outputPath =
          path.toLowerCase().endsWith('.${SshBackupService.fileExtension}')
          ? path
          : '$path.${SshBackupService.fileExtension}';
      if (!pickerWritesFile) {
        await const SshBackupFileService().writeAtomically(
          outputPath,
          backupBytes,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sshExportSuccess(selected.length))),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showOutputDialog(
          context,
          l10n.sshExportFailed(localizeError(l10n, error)),
        );
      }
    } finally {
      backupBytes?.fillRange(0, backupBytes.length, 0);
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<void> _importBackup() async {
    if (_isTransferring || _busyProfileId != null) return;
    final l10n = AppLocalizations.of(context);
    String? path;
    try {
      path = await (widget.importPathPicker?.call() ?? _pickImportPath());
    } on Object catch (error) {
      if (mounted) {
        showOutputDialog(
          context,
          l10n.sshBackupFilePickFailed(localizeError(l10n, error)),
        );
      }
      return;
    }
    if (path == null || !mounted) return;
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _SshBackupPasswordDialog(),
    );
    if (password == null || !mounted) return;

    setState(() => _isTransferring = true);
    try {
      final entries = await _backupService.decrypt(
        await const SshBackupFileService().read(File(path)),
        password,
      );
      final expectedProfiles = await widget.profileStore.load();
      if (!mounted) return;
      final planned = _importService.plan(entries, expectedProfiles);
      final decisions = await showDialog<List<SshBackupImportItem>>(
        context: context,
        builder: (context) => _SshBackupImportPreviewDialog(items: planned),
      );
      if (decisions == null || !mounted) return;
      final result = await _importService.apply(decisions, expectedProfiles);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.sshImportSummary(
              result.imported,
              result.replaced,
              result.skipped,
            ),
          ),
        ),
      );
      if (result.cleanupWarnings.isNotEmpty) {
        showOutputDialog(
          context,
          result.cleanupWarnings
              .map((warning) => localizeImportWarning(l10n, warning))
              .join('\n'),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showOutputDialog(
          context,
          l10n.sshImportFailed(localizeError(l10n, error)),
        );
      }
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<String?> _pickImportPath() async {
    final selection = await FilePicker.platform.pickFiles(
      dialogTitle: AppLocalizations.of(context).sshImportDialogTitle,
      type: FileType.custom,
      allowedExtensions: const [SshBackupService.fileExtension],
    );
    return selection?.files.single.path;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filteredProfiles = _filteredProfiles;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sshPageTitle),
        actions: [
          IconButton(
            key: const Key('import-ssh-backup'),
            tooltip: l10n.sshImportBackupTooltip,
            onPressed: _isTransferring || _busyProfileId != null
                ? null
                : _importBackup,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            key: const Key('export-ssh-backup'),
            tooltip: l10n.sshExportBackupTooltip,
            onPressed:
                _profiles.isEmpty || _isTransferring || _busyProfileId != null
                ? null
                : _exportBackup,
            icon: const Icon(Icons.file_upload_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(_error!, textAlign: TextAlign.center),
              ),
            )
          : _profiles.isEmpty
          ? Center(child: Text(l10n.sshNoProfilesYet))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: TextField(
                    key: const Key('search-ssh-profiles'),
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.sshSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              key: const Key('clear-ssh-profile-search'),
                              tooltip: l10n.sshClearSearch,
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: filteredProfiles.isEmpty
                      ? Center(child: Text(l10n.sshNoProfilesFound))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredProfiles.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, index) {
                            final profile = filteredProfiles[index];
                            final busy = _busyProfileId == profile.id;
                            final actionsDisabled =
                                _busyProfileId != null || _isTransferring;
                            return Card(
                              key: Key('ssh-profile-${profile.id}'),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.dns_outlined),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                profile.name,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(profile.endpoint),
                                              Text(
                                                profile.authenticationType ==
                                                        SshAuthenticationType
                                                            .privateKey
                                                    ? l10n.sshAuthenticationKeyLabel
                                                    : l10n.sshAuthenticationPasswordLabel,
                                              ),
                                              Text(
                                                profile.hostKeyFingerprint ==
                                                        null
                                                    ? l10n.sshHostKeyUnconfirmed
                                                    : l10n.sshHostKeyConfirmed,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: actionsDisabled
                                              ? null
                                              : () => _test(profile),
                                          icon: const Icon(Icons.network_check),
                                          label: Text(l10n.sshTest),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: actionsDisabled
                                              ? null
                                              : () => _edit(profile),
                                          icon: const Icon(Icons.edit_outlined),
                                          label: Text(l10n.sshEdit),
                                        ),
                                        OutlinedButton.icon(
                                          key: Key(
                                            'delete-ssh-profile-${profile.id}',
                                          ),
                                          onPressed: actionsDisabled
                                              ? null
                                              : () => _delete(profile),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: Text(l10n.commonDelete),
                                        ),
                                        FilledButton.icon(
                                          key: Key(
                                            'connect-ssh-profile-${profile.id}',
                                          ),
                                          onPressed: actionsDisabled
                                              ? null
                                              : () => _connect(profile),
                                          icon: busy
                                              ? const SizedBox.square(
                                                  dimension: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(Icons.terminal),
                                          label: Text(l10n.sshConnect),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-ssh-profile'),
        onPressed: _busyProfileId == null && !_isTransferring ? _edit : null,
        icon: const Icon(Icons.add),
        label: Text(l10n.sshAddConnection),
      ),
    );
  }
}
