import 'package:flutter/material.dart';

import '../models/ssh_connection_profile.dart';
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

  const SshConnectionsPage({
    super.key,
    required this.profileStore,
    required this.credentialStore,
    required this.hostKeyVerifier,
  });

  @override
  State<SshConnectionsPage> createState() => _SshConnectionsPageState();
}

class _SshConnectionsPageState extends State<SshConnectionsPage> {
  List<SshConnectionProfile> _profiles = const [];
  bool _loading = true;
  String? _error;
  String? _busyProfileId;

  @override
  void initState() {
    super.initState();
    _load();
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
    final result = await showDialog<_SshProfileInput>(
      context: context,
      builder: (context) => _SshProfileDialog(profile: existing),
    );
    if (result == null || !mounted) return;

    final endpointChanged =
        existing != null &&
        (existing.host != result.host || existing.port != result.port);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final profileId = existing?.id ?? 'ssh-$timestamp';
    final passwordChanged = result.password.isNotEmpty;
    final credentialId = passwordChanged
        ? 'credential-$timestamp'
        : existing?.credentialId ?? 'credential-$timestamp';
    final profile = SshConnectionProfile(
      id: profileId,
      name: result.name,
      host: result.host,
      port: result.port,
      username: result.username,
      credentialId: credentialId,
      hostKeyType: endpointChanged ? null : existing?.hostKeyType,
      hostKeyFingerprint: endpointChanged ? null : existing?.hostKeyFingerprint,
    );
    setState(() => _busyProfileId = profile.id);
    try {
      final oldCredentialId = existing?.credentialId;
      final oldPassword = oldCredentialId == null
          ? null
          : await widget.credentialStore.readPassword(oldCredentialId);
      final newPassword = result.password.isEmpty
          ? oldPassword
          : result.password;
      if (newPassword == null || newPassword.isEmpty) {
        throw StateError('Bitte gib ein SSH-Passwort ein.');
      }
      await widget.profileStore.upsert(profile);
      if (passwordChanged) {
        try {
          await widget.credentialStore.writePassword(
            profile.credentialId,
            result.password,
          );
        } on Object catch (credentialError) {
          try {
            await widget.credentialStore.deletePassword(profile.credentialId);
          } on Object catch (cleanupError) {
            throw StateError(
              'Das Profil wurde gespeichert, aber das neue Passwort konnte '
              'weder vollständig geschrieben noch entfernt werden: '
              '$credentialError; $cleanupError',
            );
          }
          try {
            if (existing == null) {
              await widget.profileStore.delete(profile.id);
            } else {
              await widget.profileStore.upsert(existing);
            }
          } on Object catch (rollbackError) {
            throw StateError(
              'Das Passwort konnte nicht gespeichert und die Profiländerung '
              'nicht zurückgesetzt werden: $credentialError; $rollbackError',
            );
          }
          rethrow;
        }
      }
      Object? cleanupError;
      if (passwordChanged &&
          oldCredentialId != null &&
          oldCredentialId != profile.credentialId) {
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
          'Das Profil wurde gespeichert, aber das vorherige Passwort konnte '
          'nicht aus dem Schlüsselbund entfernt werden: $cleanupError',
        );
      }
    } on Object catch (error) {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SSH-Verbindung löschen?'),
        content: Text(
          'Soll „${profile.name}“ einschließlich des gespeicherten Passworts '
          'gelöscht werden?',
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
      await widget.profileStore.delete(profile.id);
      Object? cleanupError;
      try {
        await widget.credentialStore.deletePassword(profile.credentialId);
      } on Object catch (error) {
        cleanupError = error;
      }
      await _load();
      if (cleanupError != null && mounted) {
        showOutputDialog(
          context,
          'Das Profil wurde gelöscht, aber das Passwort konnte nicht aus dem '
          'Schlüsselbund entfernt werden: $cleanupError',
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
    setState(() => _busyProfileId = profile.id);
    try {
      final password = await widget.credentialStore.readPassword(
        profile.credentialId,
      );
      if (password == null || password.isEmpty) {
        throw StateError('Im Schlüsselbund ist kein Passwort gespeichert.');
      }
      final backend = await SshTerminalBackend.connect(
        profile: profile,
        password: password,
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
    setState(() => _busyProfileId = profile.id);
    try {
      final password = await widget.credentialStore.readPassword(
        profile.credentialId,
      );
      if (password == null || password.isEmpty) {
        throw StateError('Im Schlüsselbund ist kein Passwort gespeichert.');
      }
      if (!mounted) return;
      final controller = TerminalPanelScope.of(context);
      await controller.createSshTab(profile);
      await controller.open();
      await _load();
    } on Object catch (error) {
      if (mounted) {
        showOutputDialog(context, 'SSH-Verbindung fehlgeschlagen: $error');
      }
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH-Verbindungen'),
        actions: const [TerminalPanelToggleButton()],
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
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _profiles.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final profile = _profiles[index];
                final busy = _busyProfileId == profile.id;
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    profile.hostKeyFingerprint == null
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
                              onPressed: busy ? null : () => _test(profile),
                              icon: const Icon(Icons.network_check),
                              label: const Text('Testen'),
                            ),
                            OutlinedButton.icon(
                              onPressed: busy ? null : () => _edit(profile),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Bearbeiten'),
                            ),
                            OutlinedButton.icon(
                              key: Key('delete-ssh-profile-${profile.id}'),
                              onPressed: busy ? null : () => _delete(profile),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Löschen'),
                            ),
                            FilledButton.icon(
                              key: Key('connect-ssh-profile-${profile.id}'),
                              onPressed: busy ? null : () => _connect(profile),
                              icon: busy
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
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
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-ssh-profile'),
        onPressed: _busyProfileId == null ? _edit : null,
        icon: const Icon(Icons.add),
        label: const Text('Verbindung hinzufügen'),
      ),
    );
  }
}

class _SshProfileInput {
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;

  const _SshProfileInput({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
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
  final _passwordController = TextEditingController();
  var _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _hostController = TextEditingController(text: profile?.host ?? '');
    _portController = TextEditingController(text: '${profile?.port ?? 22}');
    _usernameController = TextEditingController(text: profile?.username ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
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
                TextFormField(
                  key: const Key('ssh-profile-password'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: editing
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
                  validator: (value) =>
                      !editing && (value == null || value.isEmpty)
                      ? 'Passwort darf nicht leer sein.'
                      : null,
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Das Passwort wird ausschließlich im Schlüsselbund des '
                    'Betriebssystems gespeichert.',
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _SshProfileInput(
        name: _nameController.text.trim(),
        host: _hostController.text.trim(),
        port: int.parse(_portController.text.trim()),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }
}
