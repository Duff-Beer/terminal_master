import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/ssh_connection_profile.dart';
import '../services/ssh_authentication.dart';
import '../services/ssh_backup_import_service.dart';
import '../services/ssh_backup_service.dart';
import '../services/ssh_connection_profile_store.dart';
import '../services/ssh_credential_store.dart';
import '../services/ssh_host_key_verifier.dart';
import '../services/ssh_terminal_backend.dart';
import '../widgets/output_dialog.dart';
import '../widgets/terminal_panel.dart';

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
          throw StateError(
            'Das SSH-Profil wurde zwischenzeitlich geändert. Öffne es erneut.',
          );
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
        throw StateError('Bitte gib ein SSH-Passwort ein.');
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
        throw StateError(
          'Die SSH-Profile wurden zwischenzeitlich geändert. Versuche es erneut.',
        );
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
          'Das Profil wurde gespeichert, aber die vorherigen Anmeldedaten '
          'konnten nicht aus dem Schlüsselbund entfernt werden: $cleanupError',
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
              'SSH-Profil konnte nicht gespeichert werden: $error\n'
              'Zusätzlich konnten temporäre Anmeldedaten nicht entfernt '
              'werden: $cleanupError',
            );
          }
          return;
        }
      }
      if (mounted) {
        showOutputDialog(
          context,
          'SSH-Profil konnte nicht gespeichert werden: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _delete(SshConnectionProfile profile) async {
    if (_busyProfileId != null || _isTransferring) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SSH-Verbindung löschen?'),
        content: Text(
          'Soll „${profile.name}“ einschließlich der gespeicherten '
          'Anmeldedaten gelöscht werden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const Key('confirm-delete-ssh-profile'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
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
        throw StateError(
          'Das SSH-Profil wurde zwischenzeitlich geändert. Lösche es erneut.',
        );
      }
      final remainingProfiles = expectedProfiles
          .where((candidate) => candidate.id != profile.id)
          .toList(growable: false);
      final deleted = await widget.profileStore.replaceAllIfUnchanged(
        expected: expectedProfiles,
        replacement: remainingProfiles,
      );
      if (!deleted) {
        throw StateError(
          'Die SSH-Profile wurden zwischenzeitlich geändert. Versuche es erneut.',
        );
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
          'Das Profil wurde gelöscht, aber die Anmeldedaten konnten nicht aus '
          'dem Schlüsselbund entfernt werden: $cleanupError',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showOutputDialog(
          context,
          'SSH-Profil konnte nicht gelöscht werden: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _test(SshConnectionProfile profile) async {
    if (_busyProfileId != null || _isTransferring) return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SSH-Verbindung erfolgreich.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showOutputDialog(context, 'SSH-Verbindung fehlgeschlagen: $error');
      }
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _connect(SshConnectionProfile profile) async {
    if (_busyProfileId != null || _isTransferring) return;
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
        showOutputDialog(context, 'SSH-Verbindung fehlgeschlagen: $error');
      }
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _exportBackup() async {
    if (_profiles.isEmpty || _isTransferring || _busyProfileId != null) return;
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
                dialogTitle: 'Verschlüsseltes SSH-Backup exportieren',
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
        await _writeBackupAtomically(outputPath, backupBytes);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selected.length} SSH-Verbindungen verschlüsselt exportiert.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showOutputDialog(context, 'SSH-Export fehlgeschlagen: $error');
      }
    } finally {
      backupBytes?.fillRange(0, backupBytes.length, 0);
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<void> _importBackup() async {
    if (_isTransferring || _busyProfileId != null) return;
    String? path;
    try {
      path = await (widget.importPathPicker?.call() ?? _pickImportPath());
    } on Object catch (error) {
      if (mounted) {
        showOutputDialog(
          context,
          'Backup-Datei konnte nicht gewählt werden: $error',
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
        await _readBackupFile(File(path)),
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
            '${result.imported} importiert, ${result.replaced} ersetzt, '
            '${result.skipped} übersprungen.',
          ),
        ),
      );
      if (result.cleanupWarnings.isNotEmpty) {
        showOutputDialog(context, result.cleanupWarnings.join('\n'));
      }
    } on Object catch (error) {
      if (mounted) {
        showOutputDialog(context, 'SSH-Import fehlgeschlagen: $error');
      }
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<String?> _pickImportPath() async {
    final selection = await FilePicker.platform.pickFiles(
      dialogTitle: 'Verschlüsseltes SSH-Backup importieren',
      type: FileType.custom,
      allowedExtensions: const [SshBackupService.fileExtension],
    );
    return selection?.files.single.path;
  }

  Future<String> _readBackupFile(File file) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > SshBackupService.maximumFileBytes) {
        throw const SshBackupException('Die Backup-Datei ist zu groß.');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  Future<void> _writeBackupAtomically(String path, Uint8List bytes) async {
    final temporary = File(
      '$path.tmp-$pid-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProfiles = _filteredProfiles;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH-Verbindungen'),
        actions: [
          IconButton(
            key: const Key('import-ssh-backup'),
            tooltip: 'Verschlüsseltes Backup importieren',
            onPressed: _isTransferring || _busyProfileId != null
                ? null
                : _importBackup,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            key: const Key('export-ssh-backup'),
            tooltip: 'Verschlüsseltes Backup exportieren',
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
          ? const Center(
              child: Text('Noch keine SSH-Verbindungen gespeichert.'),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: TextField(
                    key: const Key('search-ssh-profiles'),
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'SSH-Verbindungen durchsuchen',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              key: const Key('clear-ssh-profile-search'),
                              tooltip: 'Suche löschen',
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
                      ? const Center(
                          child: Text('Keine SSH-Verbindungen gefunden.'),
                        )
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
                                                    ? 'Authentifizierung: SSH-Key'
                                                    : 'Authentifizierung: Passwort',
                                              ),
                                              Text(
                                                profile.hostKeyFingerprint ==
                                                        null
                                                    ? 'Host-Key nicht bestätigt'
                                                    : 'Host-Key bestätigt',
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
                                          label: const Text('Testen'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: actionsDisabled
                                              ? null
                                              : () => _edit(profile),
                                          icon: const Icon(Icons.edit_outlined),
                                          label: const Text('Bearbeiten'),
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
                                          label: const Text('Löschen'),
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
                                          label: const Text('Verbinden'),
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
        label: const Text('Verbindung hinzufügen'),
      ),
    );
  }
}

class _SshBackupExportRequest {
  final Set<String> profileIds;
  final String password;

  const _SshBackupExportRequest({
    required this.profileIds,
    required this.password,
  });
}

class _SshBackupExportDialog extends StatefulWidget {
  final List<SshConnectionProfile> profiles;

  const _SshBackupExportDialog({required this.profiles});

  @override
  State<_SshBackupExportDialog> createState() => _SshBackupExportDialogState();
}

class _SshBackupExportDialogState extends State<_SshBackupExportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  late final Set<String> _selectedIds;
  var _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.profiles.map((profile) => profile.id).toSet();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verschlüsseltes SSH-Backup'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Das Backup enthält die ausgewählten Verbindungen und deren '
                  'Passwörter beziehungsweise Key-Passphrases. Private '
                  'Schlüsseldateien werden nicht eingebettet. Das Backup wird '
                  'mit Argon2id und AES-256-GCM geschützt.',
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView(
                    shrinkWrap: true,
                    children: widget.profiles.map((profile) {
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(profile.name),
                        subtitle: Text(profile.endpoint),
                        value: _selectedIds.contains(profile.id),
                        onChanged: (selected) => setState(() {
                          if (selected == true) {
                            _selectedIds.add(profile.id);
                          } else {
                            _selectedIds.remove(profile.id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('ssh-backup-export-password'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Backup-Passwort',
                    helperText: 'Mindestens 12 Zeichen',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => (value?.length ?? 0) < 12
                      ? 'Mindestens 12 Zeichen erforderlich.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('ssh-backup-export-confirmation'),
                  controller: _confirmationController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Backup-Passwort wiederholen',
                  ),
                  validator: (value) => value != _passwordController.text
                      ? 'Die Passwörter stimmen nicht überein.'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('confirm-export-ssh-backup'),
          onPressed: _submit,
          child: const Text('Exportieren'),
        ),
      ],
    );
  }

  void _submit() {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wähle mindestens eine Verbindung aus.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _SshBackupExportRequest(
        profileIds: Set.unmodifiable(_selectedIds),
        password: _passwordController.text,
      ),
    );
  }
}

class _SshBackupPasswordDialog extends StatefulWidget {
  const _SshBackupPasswordDialog();

  @override
  State<_SshBackupPasswordDialog> createState() =>
      _SshBackupPasswordDialogState();
}

class _SshBackupPasswordDialogState extends State<_SshBackupPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  var _obscurePassword = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('SSH-Backup entschlüsseln'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('ssh-backup-import-password'),
          controller: _controller,
          autofocus: true,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Backup-Passwort',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) => value == null || value.isEmpty
              ? 'Backup-Passwort erforderlich.'
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('open-ssh-backup'),
          onPressed: _submit,
          child: const Text('Entschlüsseln'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _controller.text);
  }
}

class _SshBackupImportPreviewDialog extends StatefulWidget {
  final List<SshBackupImportItem> items;

  const _SshBackupImportPreviewDialog({required this.items});

  @override
  State<_SshBackupImportPreviewDialog> createState() =>
      _SshBackupImportPreviewDialogState();
}

class _SshBackupImportPreviewDialogState
    extends State<_SshBackupImportPreviewDialog> {
  late List<SshBackupImportItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
  }

  @override
  Widget build(BuildContext context) {
    final actionable = _items.any(
      (item) => item.action != SshBackupConflictAction.skip,
    );
    return AlertDialog(
      title: const Text('SSH-Import prüfen'),
      content: SizedBox(
        width: 720,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _items.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final item = _items[index];
              final existingFingerprint = item.existing?.hostKeyFingerprint;
              final importedFingerprint = item.entry.hostKeyFingerprint;
              final hostKeyConflict =
                  (existingFingerprint != null ||
                      importedFingerprint != null) &&
                  existingFingerprint != importedFingerprint;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.entry.name),
                subtitle: Text(
                  '${item.entry.endpoint}\n'
                  '${item.entry.authenticationType == SshAuthenticationType.privateKey ? 'SSH-Key' : 'Passwort'}\n'
                  '${item.duplicateInBackup
                      ? 'Doppelter Endpunkt im Backup'
                      : item.hasConflict
                      ? 'Vorhandene Verbindung gefunden'
                      : 'Neue Verbindung'}'
                  '${hostKeyConflict ? '\nWarnung: Host-Key unterscheidet sich' : ''}',
                  style: hostKeyConflict
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
                isThreeLine: true,
                trailing: item.hasConflict
                    ? DropdownButton<SshBackupConflictAction>(
                        key: Key('ssh-import-action-$index'),
                        value: item.action,
                        items: [
                          const DropdownMenuItem(
                            value: SshBackupConflictAction.skip,
                            child: Text('Überspringen'),
                          ),
                          if (item.existing != null)
                            const DropdownMenuItem(
                              value: SshBackupConflictAction.replace,
                              child: Text('Ersetzen'),
                            ),
                          const DropdownMenuItem(
                            value: SshBackupConflictAction.copy,
                            child: Text('Als Kopie'),
                          ),
                        ],
                        onChanged: (action) {
                          if (action == null) return;
                          setState(
                            () => _items[index] = item.copyWith(action: action),
                          );
                        },
                      )
                    : const Chip(label: Text('Neu')),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('confirm-import-ssh-backup'),
          onPressed: actionable
              ? () => Navigator.pop<List<SshBackupImportItem>>(
                  context,
                  List<SshBackupImportItem>.unmodifiable(_items),
                )
              : null,
          child: const Text('Importieren'),
        ),
      ],
    );
  }
}

class _SshProfileInput {
  final String name;
  final String host;
  final int port;
  final String username;
  final SshAuthenticationType authenticationType;
  final String? privateKeyPath;
  final String secret;
  final bool clearSecret;

  const _SshProfileInput({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.authenticationType,
    this.privateKeyPath,
    required this.secret,
    required this.clearSecret,
  });
}

class _SshProfileDialog extends StatefulWidget {
  final SshConnectionProfile? profile;

  const _SshProfileDialog({this.profile});

  @override
  State<_SshProfileDialog> createState() => _SshProfileDialogState();
}

class _SshProfileDialogState extends State<_SshProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _privateKeyPathController;
  final _secretController = TextEditingController();
  late SshAuthenticationType _authenticationType;
  var _clearSecret = false;
  var _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _hostController = TextEditingController(text: profile?.host ?? '');
    _portController = TextEditingController(text: '${profile?.port ?? 22}');
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _privateKeyPathController = TextEditingController(
      text: profile?.privateKeyPath ?? '',
    );
    _authenticationType =
        profile?.authenticationType ?? SshAuthenticationType.password;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _privateKeyPathController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.profile != null;
    return AlertDialog(
      title: Text(
        editing ? 'SSH-Verbindung bearbeiten' : 'SSH-Verbindung hinzufügen',
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(
                  key: const Key('ssh-profile-name'),
                  controller: _nameController,
                  label: 'Anzeigename',
                ),
                const SizedBox(height: 12),
                _field(
                  key: const Key('ssh-profile-host'),
                  controller: _hostController,
                  label: 'Serveradresse',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('ssh-profile-port'),
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Port'),
                  validator: (value) {
                    final port = int.tryParse(value?.trim() ?? '');
                    return port == null || port < 1 || port > 65535
                        ? 'Port muss zwischen 1 und 65535 liegen.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  key: const Key('ssh-profile-username'),
                  controller: _usernameController,
                  label: 'Benutzername',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SshAuthenticationType>(
                  key: const Key('ssh-profile-authentication-type'),
                  initialValue: _authenticationType,
                  decoration: const InputDecoration(
                    labelText: 'Authentifizierung',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: SshAuthenticationType.password,
                      child: Text('Passwort'),
                    ),
                    DropdownMenuItem(
                      value: SshAuthenticationType.privateKey,
                      enabled: !Platform.isAndroid && !Platform.isIOS,
                      child: Text(
                        Platform.isAndroid || Platform.isIOS
                            ? 'SSH-Key (Desktop)'
                            : 'SSH-Key',
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _authenticationType = value);
                  },
                ),
                if (_authenticationType ==
                    SshAuthenticationType.privateKey) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('ssh-profile-private-key-path'),
                    controller: _privateKeyPathController,
                    decoration: InputDecoration(
                      labelText: 'Private Schlüsseldatei',
                      suffixIcon: IconButton(
                        key: const Key('pick-ssh-private-key'),
                        tooltip: 'Schlüsseldatei auswählen',
                        onPressed: _pickPrivateKey,
                        icon: const Icon(Icons.folder_open_outlined),
                      ),
                    ),
                    validator: (value) {
                      if (_authenticationType !=
                          SshAuthenticationType.privateKey) {
                        return null;
                      }
                      return value == null || value.trim().isEmpty
                          ? 'Wähle eine private Schlüsseldatei aus.'
                          : null;
                    },
                  ),
                  if (editing &&
                      widget.profile!.authenticationType ==
                          SshAuthenticationType.privateKey) ...[
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      key: const Key('clear-ssh-key-passphrase'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Gespeicherte Passphrase entfernen'),
                      value: _clearSecret,
                      onChanged: (value) => setState(() {
                        _clearSecret = value ?? false;
                        if (_clearSecret) _secretController.clear();
                      }),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('ssh-profile-password'),
                  controller: _secretController,
                  enabled: !_clearSecret,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText:
                        _authenticationType == SshAuthenticationType.privateKey
                        ? editing
                              ? 'Key-Passphrase (leer lassen zum Beibehalten)'
                              : 'Key-Passphrase (optional)'
                        : editing
                        ? 'Neues Passwort (leer lassen zum Beibehalten)'
                        : 'Passwort',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Passwort anzeigen'
                          : 'Passwort ausblenden',
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final requiresPassword =
                        _authenticationType == SshAuthenticationType.password &&
                        (!editing ||
                            widget.profile!.authenticationType !=
                                SshAuthenticationType.password);
                    return requiresPassword && (value == null || value.isEmpty)
                        ? 'Passwort darf nicht leer sein.'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Passwörter und Key-Passphrases werden ausschließlich im '
                    'Schlüsselbund des Betriebssystems gespeichert. Private '
                    'Schlüssel verbleiben in der ausgewählten Datei.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('save-ssh-profile'),
          onPressed: _submit,
          child: const Text('Speichern'),
        ),
      ],
    );
  }

  TextFormField _field({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) => value == null || value.trim().isEmpty
          ? '$label darf nicht leer sein.'
          : value.runes.any((rune) => rune < 0x20 || rune == 0x7f)
          ? '$label enthält ungültige Steuerzeichen.'
          : null,
    );
  }

  Future<void> _pickPrivateKey() async {
    if (Platform.isAndroid || Platform.isIOS) {
      showOutputDialog(
        context,
        'SSH-Key-Dateien werden derzeit nur auf Desktop-Plattformen '
        'unterstützt, da mobile Dateiauswahlen keine dauerhaft nutzbaren '
        'Pfade bereitstellen.',
      );
      return;
    }
    final selection = await FilePicker.platform.pickFiles(
      dialogTitle: 'Private SSH-Schlüsseldatei auswählen',
      type: FileType.any,
    );
    final path = selection?.files.single.path;
    if (path != null && mounted) {
      setState(() => _privateKeyPathController.text = path);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _SshProfileInput(
        name: _nameController.text.trim(),
        host: _hostController.text.trim(),
        port: int.parse(_portController.text.trim()),
        username: _usernameController.text.trim(),
        authenticationType: _authenticationType,
        privateKeyPath: _authenticationType == SshAuthenticationType.privateKey
            ? _privateKeyPathController.text.trim()
            : null,
        secret: _secretController.text,
        clearSecret: _clearSecret,
      ),
    );
  }
}
