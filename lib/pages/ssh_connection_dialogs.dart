part of 'ssh_connections_page.dart';

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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.sshBackupDialogTitle),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.sshBackupExportExplanation),
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
                    labelText: l10n.sshBackupPasswordLabel,
                    helperText: l10n.sshBackupPasswordHelper,
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
                      ? l10n.sshBackupPasswordTooShort
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('ssh-backup-export-confirmation'),
                  controller: _confirmationController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.sshBackupPasswordRepeatLabel,
                  ),
                  validator: (value) => value != _passwordController.text
                      ? l10n.sshBackupPasswordMismatch
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
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('confirm-export-ssh-backup'),
          onPressed: _submit,
          child: Text(l10n.sshExport),
        ),
      ],
    );
  }

  void _submit() {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).sshSelectAtLeastOne),
        ),
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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.sshBackupDecryptTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('ssh-backup-import-password'),
          controller: _controller,
          autofocus: true,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: l10n.sshBackupPasswordLabel,
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
              ? l10n.sshBackupPasswordNeeded
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('open-ssh-backup'),
          onPressed: _submit,
          child: Text(l10n.sshDecrypt),
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
    final l10n = AppLocalizations.of(context);
    final actionable = _items.any(
      (item) => item.action != SshBackupConflictAction.skip,
    );
    return AlertDialog(
      title: Text(l10n.sshImportReviewTitle),
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
                  '${item.entry.authenticationType == SshAuthenticationType.privateKey ? l10n.sshKeyShort : l10n.sshPasswordShort}\n'
                  '${item.duplicateInBackup
                      ? l10n.sshImportDuplicateEndpoint
                      : item.hasConflict
                      ? l10n.sshImportExistingFound
                      : l10n.sshImportNewConnection}'
                  '${hostKeyConflict ? '\n${l10n.sshImportHostKeyWarning}' : ''}',
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
                          DropdownMenuItem(
                            value: SshBackupConflictAction.skip,
                            child: Text(l10n.sshImportSkip),
                          ),
                          if (item.existing != null)
                            DropdownMenuItem(
                              value: SshBackupConflictAction.replace,
                              child: Text(l10n.sshImportReplace),
                            ),
                          DropdownMenuItem(
                            value: SshBackupConflictAction.copy,
                            child: Text(l10n.sshImportAsCopy),
                          ),
                        ],
                        onChanged: (action) {
                          if (action == null) return;
                          setState(
                            () => _items[index] = item.copyWith(action: action),
                          );
                        },
                      )
                    : Chip(label: Text(l10n.sshImportNew)),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('confirm-import-ssh-backup'),
          onPressed: actionable
              ? () => Navigator.pop<List<SshBackupImportItem>>(
                  context,
                  List<SshBackupImportItem>.unmodifiable(_items),
                )
              : null,
          child: Text(l10n.sshImport),
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
    final l10n = AppLocalizations.of(context);
    final editing = widget.profile != null;
    return AlertDialog(
      title: Text(editing ? l10n.sshEditTitle : l10n.sshAddTitle),
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
                  label: l10n.sshFieldDisplayName,
                ),
                const SizedBox(height: 12),
                _field(
                  key: const Key('ssh-profile-host'),
                  controller: _hostController,
                  label: l10n.sshFieldHost,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('ssh-profile-port'),
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.sshFieldPort),
                  validator: (value) {
                    final port = int.tryParse(value?.trim() ?? '');
                    return port == null || port < 1 || port > 65535
                        ? l10n.sshPortRange
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  key: const Key('ssh-profile-username'),
                  controller: _usernameController,
                  label: l10n.sshFieldUsername,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SshAuthenticationType>(
                  key: const Key('ssh-profile-authentication-type'),
                  initialValue: _authenticationType,
                  decoration: InputDecoration(
                    labelText: l10n.sshFieldAuthentication,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: SshAuthenticationType.password,
                      child: Text(l10n.sshPasswordShort),
                    ),
                    DropdownMenuItem(
                      value: SshAuthenticationType.privateKey,
                      enabled: !Platform.isAndroid && !Platform.isIOS,
                      child: Text(
                        Platform.isAndroid || Platform.isIOS
                            ? l10n.sshAuthenticationKeyDesktop
                            : l10n.sshKeyShort,
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
                      labelText: l10n.sshFieldPrivateKeyFile,
                      suffixIcon: IconButton(
                        key: const Key('pick-ssh-private-key'),
                        tooltip: l10n.sshPickKeyFile,
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
                          ? l10n.sshPrivateKeyRequired
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
                      title: Text(l10n.sshClearStoredPassphrase),
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
                              ? l10n.sshKeyPassphraseKeep
                              : l10n.sshKeyPassphraseOptional
                        : editing
                        ? l10n.sshPasswordKeep
                        : l10n.sshPasswordLabel,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? l10n.sshShowPassword
                          : l10n.sshHidePassword,
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
                        ? l10n.sshPasswordNotEmpty
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.sshCredentialStorageNote),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('save-ssh-profile'),
          onPressed: _submit,
          child: Text(l10n.sshSave),
        ),
      ],
    );
  }

  TextFormField _field({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      key: key,
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) => value == null || value.trim().isEmpty
          ? l10n.sshFieldNotEmpty(label)
          : value.runes.any((rune) => rune < 0x20 || rune == 0x7f)
          ? l10n.sshFieldInvalidControlCharacters(label)
          : null,
    );
  }

  Future<void> _pickPrivateKey() async {
    if (Platform.isAndroid || Platform.isIOS) {
      showOutputDialog(
        context,
        AppLocalizations.of(context).sshKeyFilesDesktopOnly,
      );
      return;
    }
    final selection = await FilePicker.platform.pickFiles(
      dialogTitle: AppLocalizations.of(context).sshPickPrivateKeyDialogTitle,
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
