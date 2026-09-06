import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  String? _loadError;
  late String _configSource;

  @override
  void initState() {
    super.initState();
    _loadBatchFile();
  }

  void _loadBatchFile() {
    try {
      _commands = ConfigLoader.loadBatchConfig(widget.filePath).commands;
      _configSource = File(widget.filePath).readAsStringSync();
      _loadError = null;
    } on Object catch (error) {
      _loadError = error.toString();
    }
  }

  Future<void> _addCommand() async {
    var title = '';
    var description = '';
    var commandText = '';
    final command = await showDialog<BatchCommand>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batch Command hinzufügen'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('new-batch-command-title'),
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Titel *'),
                onChanged: (value) => title = value,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('new-batch-command-description'),
                decoration: const InputDecoration(labelText: 'Beschreibung'),
                onChanged: (value) => description = value,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('new-batch-command-command'),
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Befehl *'),
                onChanged: (value) => commandText = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
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
            child: const Text('Hinzufügen'),
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
        'Befehl konnte nicht gespeichert werden: $error',
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _deleteCommand(int index) async {
    final command = _commands[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batch Command löschen?'),
        content: Text('Soll „${command.title}“ dauerhaft gelöscht werden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const Key('confirm-delete-batch-command'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
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
      showOutputDialog(context, 'Befehl konnte nicht gelöscht werden: $error');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _stageCommand(BatchCommand command) async {
    if (_isStaging || command.command.isEmpty) return;
    setState(() => _isStaging = true);
    try {
      await TerminalPanelScope.of(context).insertCommand(command.command);
      if (mounted) ConfigurationPanelScope.maybeOf(context)?.close();
    } on Object catch (error) {
      if (!mounted) return;
      showOutputDialog(context, 'Fehler beim Einfügen: $error');
    } finally {
      if (mounted) setState(() => _isStaging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Konfigurationsfehler')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(_loadError!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Commands'),
        actions: [
          IconButton(
            key: const Key('add-batch-command'),
            tooltip: 'Batch Command hinzufügen',
            onPressed: _isStaging || _isMutating ? null : _addCommand,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _commands.isEmpty
          ? const Center(child: Text('Keine Befehle gefunden.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _commands.length,
              itemBuilder: (context, index) {
                final command = _commands[index];
                return ListTile(
                  title: Text(command.title),
                  subtitle: Text(command.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('stage-batch-command-$index'),
                        icon: const Icon(Icons.play_arrow),
                        tooltip: 'Ins interne Terminal einfügen',
                        onPressed: _isStaging || _isMutating
                            ? null
                            : () => _stageCommand(command),
                      ),
                      IconButton(
                        key: Key('copy-batch-command-$index'),
                        icon: const Icon(Icons.copy),
                        tooltip: 'Befehl kopieren',
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: command.command),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Befehl in die Zwischenablage kopiert',
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        key: Key('delete-batch-command-$index'),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Batch Command löschen',
                        onPressed: _isStaging || _isMutating
                            ? null
                            : () => _deleteCommand(index),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
