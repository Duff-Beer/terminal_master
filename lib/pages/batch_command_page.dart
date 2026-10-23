import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/error_presenter.dart';
import '../models/batch_command.dart';
import '../services/batch_command_store.dart';
import '../utils/config_loader.dart';
import '../widgets/output_dialog.dart';
import '../widgets/terminal_panel.dart';

class BatchCommandPage extends StatefulWidget {
  final String filePath;

  const BatchCommandPage({super.key, required this.filePath});

  @override
  State<BatchCommandPage> createState() => _BatchCommandPageState();
}

class _BatchCommandPageState extends State<BatchCommandPage> {
  List<BatchCommand> _commands = [];
  bool _isStaging = false;
  bool _isMutating = false;
  Object? _loadError;
  late String _configSource;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Titles and descriptions come from the YAML file and are resolved per
    // language, so this reads with the active locale and re-reads on change.
    _loadBatchFile();
  }

  void _loadBatchFile() {
    try {
      _commands = ConfigLoader.loadBatchConfig(
        widget.filePath,
        languageCode: Localizations.localeOf(context).languageCode,
      ).commands;
      _configSource = File(widget.filePath).readAsStringSync();
      _loadError = null;
    } on Object catch (error) {
      _loadError = error;
    }
  }

  Future<void> _addCommand() async {
    final l10n = AppLocalizations.of(context);
    var title = '';
    var description = '';
    var commandText = '';
    final command = await showDialog<BatchCommand>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.batchAddCommand),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('new-batch-command-title'),
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.batchFieldTitle),
                onChanged: (value) => title = value,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('new-batch-command-description'),
                decoration: InputDecoration(labelText: l10n.commonDescription),
                onChanged: (value) => description = value,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('new-batch-command-command'),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.batchFieldCommand),
                onChanged: (value) => commandText = value,
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
            key: const Key('confirm-add-batch-command'),
            onPressed: () {
              if (title.trim().isEmpty || commandText.trim().isEmpty) return;
              Navigator.pop(
                context,
                BatchCommand(
                  title: title.trim(),
                  description: description.trim(),
                  command: commandText.trim(),
                ),
              );
            },
            child: Text(l10n.commonAdd),
          ),
        ],
      ),
    );
    if (command == null || !mounted) return;

    setState(() => _isMutating = true);
    try {
      await BatchCommandStore.addCommand(
        filePath: widget.filePath,
        command: command,
        expectedContent: _configSource,
      );
      if (!mounted) return;
      setState(() {
        _loadBatchFile();
      });
    } on Object catch (error) {
      if (!mounted) return;
      showOutputDialog(
        context,
        l10n.batchSaveFailed(localizeError(l10n, error)),
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _deleteCommand(int index) async {
    final l10n = AppLocalizations.of(context);
    final command = _commands[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.batchDeleteTitle),
        content: Text(l10n.batchDeleteMessage(command.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-delete-batch-command'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isMutating = true);
    try {
      await BatchCommandStore.deleteCommand(
        filePath: widget.filePath,
        commandIndex: index,
        expectedContent: _configSource,
      );
      if (!mounted) return;
      setState(() {
        _loadBatchFile();
      });
    } on Object catch (error) {
      if (!mounted) return;
      showOutputDialog(
        context,
        l10n.batchDeleteFailed(localizeError(l10n, error)),
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _stageCommand(BatchCommand command) async {
    if (_isStaging || command.command.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isStaging = true);
    try {
      await TerminalPanelScope.of(context).insertCommand(command.command);
      if (mounted) ConfigurationPanelScope.maybeOf(context)?.close();
    } on Object catch (error) {
      if (!mounted) return;
      showOutputDialog(
        context,
        l10n.batchInsertFailed(localizeError(l10n, error)),
      );
    } finally {
      if (mounted) setState(() => _isStaging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loadError case final error?) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.configErrorTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              localizeError(l10n, error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.batchTitle),
        actions: [
          IconButton(
            key: const Key('add-batch-command'),
            tooltip: l10n.batchAddCommand,
            onPressed: _isStaging || _isMutating ? null : _addCommand,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _commands.isEmpty
          ? Center(child: Text(l10n.batchNoCommands))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _commands.length,
              itemBuilder: (context, index) {
                final command = _commands[index];
                return ExpansionTile(
                  key: Key('batch-command-$index'),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          command.title.isEmpty
                              ? l10n.batchUntitled
                              : command.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        key: Key('stage-batch-command-$index'),
                        icon: const Icon(Icons.play_arrow),
                        tooltip: l10n.batchInsertIntoTerminal,
                        onPressed: _isStaging || _isMutating
                            ? null
                            : () => _stageCommand(command),
                      ),
                    ],
                  ),
                  trailing: const SizedBox.shrink(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Text(command.description),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                key: Key('copy-batch-command-$index'),
                                icon: const Icon(Icons.copy),
                                tooltip: l10n.batchCopyCommand,
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: command.command),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.batchCommandCopied),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                key: Key('delete-batch-command-$index'),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: l10n.batchDeleteCommand,
                                onPressed: _isStaging || _isMutating
                                    ? null
                                    : () => _deleteCommand(index),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
