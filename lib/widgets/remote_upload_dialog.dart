import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../l10n/app_localizations.dart';
import '../services/remote_file_upload.dart';

enum SshDropAction { upload, insertLocalPath }

class SshDropChoice {
  final SshDropAction action;

  /// The checked, absolute upload directory; only set for uploads.
  final String? remoteDirectory;

  const SshDropChoice.upload(String this.remoteDirectory)
    : action = SshDropAction.upload;

  const SshDropChoice.insertLocalPath()
    : action = SshDropAction.insertLocalPath,
      remoteDirectory = null;
}

/// Asks what to do with files dropped onto an SSH terminal and where to
/// upload them, starting from [initialDirectory]. Returns null when the drop
/// is cancelled.
Future<SshDropChoice?> showSshDropDialog(
  BuildContext context, {
  required List<String> localPaths,
  required RemoteFileSystem fileSystem,
  required String initialDirectory,
}) {
  return showDialog<SshDropChoice>(
    context: context,
    builder: (context) => _SshDropDialog(
      localPaths: localPaths,
      fileSystem: fileSystem,
      initialDirectory: initialDirectory,
    ),
  );
}

class _SshDropDialog extends StatefulWidget {
  final List<String> localPaths;
  final RemoteFileSystem fileSystem;
  final String initialDirectory;

  const _SshDropDialog({
    required this.localPaths,
    required this.fileSystem,
    required this.initialDirectory,
  });

  @override
  State<_SshDropDialog> createState() => _SshDropDialogState();
}

class _SshDropDialogState extends State<_SshDropDialog> {
  late final _directoryController = TextEditingController(
    text: widget.initialDirectory,
  );
  String? _directoryError;
  bool _checking = false;

  @override
  void dispose() {
    _directoryController.dispose();
    super.dispose();
  }

  /// Resolves the entered directory to an absolute path, or null with an
  /// error shown when it is no existing directory.
  Future<String?> _checkedDirectory() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _checking = true;
      _directoryError = null;
    });
    String? directory;
    try {
      var entered = _directoryController.text.trim();
      if (entered.isEmpty || entered == '~' || entered.startsWith('~/')) {
        final home = await widget.fileSystem.homeDirectory();
        entered = entered.length > 1
            ? path.posix.join(home, entered.substring(2))
            : home;
      }
      final resolved = await widget.fileSystem.canonicalize(entered);
      if (await widget.fileSystem.entryType(resolved) ==
          RemoteEntryType.directory) {
        directory = resolved;
      }
    } on Object {
      directory = null;
    }
    if (mounted) {
      setState(() {
        _checking = false;
        if (directory == null) {
          _directoryError = l10n.terminalUploadDirectoryMissing;
        }
      });
    }
    return directory;
  }

  Future<void> _browse() async {
    final start = await _checkedDirectory() ?? widget.initialDirectory;
    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => _RemoteDirectoryPicker(
        fileSystem: widget.fileSystem,
        initialDirectory: start,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _directoryController.text = selected;
      _directoryError = null;
    });
  }

  Future<void> _upload() async {
    final directory = await _checkedDirectory();
    if (directory != null && mounted) {
      Navigator.pop(context, SshDropChoice.upload(directory));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.cloud_upload_outlined),
      title: Text(l10n.terminalUploadTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('ssh-drop-directory'),
                    controller: _directoryController,
                    enabled: !_checking,
                    autofocus: true,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: l10n.terminalUploadTargetLabel,
                      errorText: _directoryError,
                    ),
                    onSubmitted: (_) => _upload(),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: IconButton(
                    tooltip: l10n.terminalUploadBrowse,
                    onPressed: _checking ? null : _browse,
                    icon: const Icon(Icons.folder_open_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final localPath in widget.localPaths)
                      Text(
                        path.basename(localPath),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, const SshDropChoice.insertLocalPath()),
          child: Text(l10n.terminalUploadInsertLocalPath),
        ),
        FilledButton(
          onPressed: _checking ? null : _upload,
          child: Text(l10n.terminalUploadAction),
        ),
      ],
    );
  }
}

/// Lets the user walk the remote directory tree and pick a directory.
class _RemoteDirectoryPicker extends StatefulWidget {
  final RemoteFileSystem fileSystem;
  final String initialDirectory;

  const _RemoteDirectoryPicker({
    required this.fileSystem,
    required this.initialDirectory,
  });

  @override
  State<_RemoteDirectoryPicker> createState() => _RemoteDirectoryPickerState();
}

class _RemoteDirectoryPickerState extends State<_RemoteDirectoryPicker> {
  late String _directory = widget.initialDirectory;
  List<String>? _children;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open(_directory);
  }

  Future<void> _open(String directory) async {
    setState(() {
      _children = null;
      _error = null;
    });
    try {
      final children = await widget.fileSystem.listDirectories(directory);
      if (!mounted) return;
      setState(() {
        _directory = directory;
        _children = children;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = _children;
    final parent = path.posix.dirname(_directory);
    return AlertDialog(
      title: Text(l10n.terminalUploadBrowse),
      content: SizedBox(
        width: 480,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _directory,
              style: const TextStyle(fontFamily: 'monospace'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(),
            Expanded(
              child: _error != null
                  ? Center(child: Text(l10n.terminalUploadDirectoryUnreadable))
                  : children == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        if (parent != _directory)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.arrow_upward),
                            title: const Text('..'),
                            onTap: () => _open(parent),
                          ),
                        for (final child in children)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(child),
                            onTap: () =>
                                _open(path.posix.join(_directory, child)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: children == null
              ? null
              : () => Navigator.pop(context, _directory),
          child: Text(l10n.terminalUploadSelectDirectory),
        ),
      ],
    );
  }
}

class RemoteUploadResult {
  /// Remote paths of the uploaded top-level entries.
  final List<String> remotePaths;
  final Object? error;
  final bool cancelled;

  const RemoteUploadResult.success(this.remotePaths)
    : error = null,
      cancelled = false;

  const RemoteUploadResult.failed(Object this.error)
    : remotePaths = const [],
      cancelled = false;

  const RemoteUploadResult.cancelled()
    : remotePaths = const [],
      error = null,
      cancelled = true;
}

/// Uploads [localPaths] into [remoteDirectory] while showing progress, asking
/// about conflicts on the way. The caller keeps ownership of [fileSystem].
Future<RemoteUploadResult> showRemoteUploadDialog(
  BuildContext context, {
  required RemoteFileSystem fileSystem,
  required List<String> localPaths,
  required String remoteDirectory,
}) async {
  final result = await showDialog<RemoteUploadResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _RemoteUploadDialog(
      fileSystem: fileSystem,
      localPaths: localPaths,
      remoteDirectory: remoteDirectory,
    ),
  );
  return result ?? const RemoteUploadResult.cancelled();
}

class _RemoteUploadDialog extends StatefulWidget {
  final RemoteFileSystem fileSystem;
  final List<String> localPaths;
  final String remoteDirectory;

  const _RemoteUploadDialog({
    required this.fileSystem,
    required this.localPaths,
    required this.remoteDirectory,
  });

  @override
  State<_RemoteUploadDialog> createState() => _RemoteUploadDialogState();
}

class _RemoteUploadDialogState extends State<_RemoteUploadDialog> {
  UploadProgress? _progress;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    RemoteUploadResult result;
    try {
      final uploader = RemoteFileUploader(
        fileSystem: widget.fileSystem,
        resolveConflict: _resolveConflict,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        isCancelled: () => _cancelled,
      );
      final remotePaths = await uploader.upload(
        widget.localPaths,
        remoteDirectory: widget.remoteDirectory,
      );
      result = RemoteUploadResult.success(remotePaths);
    } on UploadCancelledException {
      result = const RemoteUploadResult.cancelled();
    } catch (error) {
      result = RemoteUploadResult.failed(error);
    }
    if (mounted) Navigator.pop(context, result);
  }

  Future<UploadConflictDecision?> _resolveConflict(UploadConflict conflict) {
    if (!mounted) return Future.value();
    return showDialog<UploadConflictDecision>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UploadConflictDialog(conflict: conflict),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = _progress;
    return AlertDialog(
      title: Text(l10n.terminalUploadProgressTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: progress?.fraction),
            const SizedBox(height: 12),
            Text(
              progress == null
                  ? l10n.terminalUploadPreparing
                  : '${_formatBytes(progress.transferredBytes)} / '
                        '${_formatBytes(progress.totalBytes)}',
            ),
            if (progress != null)
              Text(
                progress.currentFile,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancelled
              ? null
              : () => setState(() => _cancelled = true),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

class _UploadConflictDialog extends StatefulWidget {
  final UploadConflict conflict;

  const _UploadConflictDialog({required this.conflict});

  @override
  State<_UploadConflictDialog> createState() => _UploadConflictDialogState();
}

class _UploadConflictDialogState extends State<_UploadConflictDialog> {
  bool _applyToAll = false;

  void _decide(UploadConflictAction action) => Navigator.pop(
    context,
    UploadConflictDecision(action, applyToAll: _applyToAll),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final conflict = widget.conflict;
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(l10n.terminalUploadConflictTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.terminalUploadConflictMessage(conflict.remotePath)),
            if (conflict.isDirectory && conflict.canOverwrite) ...[
              const SizedBox(height: 8),
              Text(l10n.terminalUploadConflictMergeHint),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _applyToAll,
              onChanged: (value) => setState(() => _applyToAll = value!),
              title: Text(l10n.terminalUploadApplyToAll),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => _decide(UploadConflictAction.skip),
          child: Text(l10n.terminalUploadSkip),
        ),
        TextButton(
          onPressed: () => _decide(UploadConflictAction.rename),
          child: Text(l10n.terminalUploadRename),
        ),
        if (conflict.canOverwrite)
          FilledButton(
            onPressed: () => _decide(UploadConflictAction.overwrite),
            child: Text(l10n.terminalUploadOverwrite),
          ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0
      ? '$bytes ${units[unit]}'
      : '${value.toStringAsFixed(1)} ${units[unit]}';
}
