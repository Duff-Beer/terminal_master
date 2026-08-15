import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/batch_command.dart';
import '../services/batch_command_store.dart';
import '../services/command_executor.dart';
import '../services/command_risk_assessor.dart';
import '../utils/config_loader.dart';
import '../widgets/command_confirmation_dialog.dart';
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
  final Set<int> _selectedIndexes = {};
  bool _runInSameTerminal = false;
  bool _useIntegratedTerminal = true;
  bool _isExecuting = false;
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
        _selectedIndexes.add(_commands.length - 1);
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
      final selected = _selectedIndexes
          .where((selectedIndex) => selectedIndex != index)
          .map(
            (selectedIndex) =>
                selectedIndex > index ? selectedIndex - 1 : selectedIndex,
          )
          .toSet();
      setState(() {
        _loadBatchFile();
        _selectedIndexes
          ..clear()
          ..addAll(selected);
      });
    } on Object catch (error) {
      if (!mounted) return;
      showOutputDialog(context, 'Befehl konnte nicht gelöscht werden: $error');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _executeSelected() async {
    if (_isExecuting) return;
    final indexes = _selectedIndexes.toList()..sort();
    final commands = indexes
        .map((index) => _commands[index].command)
        .where((command) => command.isNotEmpty)
        .toList();
    if (commands.isEmpty) return;

    setState(() => _isExecuting = true);
    try {
      final integratedCommand = commands.join('\n\n');
      if (_useIntegratedTerminal) {
        await TerminalPanelScope.of(context).insertCommand(integratedCommand);
        return;
      }
      final approved = await showCommandConfirmationDialog(
        context,
        commands: commands,
        assessment: CommandRiskAssessor.assessRawCommands(commands),
      );
      if (!mounted || !approved) return;

      if (_runInSameTerminal) {
        await CommandExecutor.executeInTerminal(commands.join(' && '), false);
      } else {
        for (final index in indexes) {
          final command = _commands[index].command;
          if (command.isNotEmpty) {
            await CommandExecutor.executeInTerminal(command, true);
          }
        }
      }
    } on Object catch (error) {
      if (!mounted) return;
      showOutputDialog(context, 'Fehler beim Ausführen: $error');
    } finally {
      if (mounted) setState(() => _isExecuting = false);
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
            onPressed: _isExecuting || _isMutating ? null : _addCommand,
            icon: const Icon(Icons.add),
          ),
          const TerminalPanelToggleButton(),
        ],
      ),
      body: _commands.isEmpty
          ? const Center(child: Text('Keine Befehle gefunden.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _commands.length + 2,
              itemBuilder: (context, index) {
                if (index == _commands.length) {
                  if (_useIntegratedTerminal) {
                    return const ListTile(
                      leading: Icon(Icons.terminal),
                      title: Text('Gemeinsame Shell-Sitzung'),
                      subtitle: Text(
                        'Befehle werden durch Leerzeilen getrennt in das '
                        'editierbare Terminalfeld übernommen.',
                      ),
                    );
                  }
                  return SwitchListTile(
                    title: const Text('Im selben Terminal ausführen'),
                    subtitle: Text(
                      _runInSameTerminal
                          ? 'Mit && verknüpfen und beim ersten Fehler stoppen'
                          : 'In getrennten externen Terminalfenstern starten',
                    ),
                    value: _runInSameTerminal,
                    onChanged: _isExecuting
                        ? null
                        : (val) => setState(() => _runInSameTerminal = val),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                  );
                }
                if (index == _commands.length + 1) {
                  return SwitchListTile(
                    key: const Key('integrated-terminal-toggle'),
                    title: const Text('Integriertes Terminal'),
                    subtitle: Text(
                      _useIntegratedTerminal
                          ? 'Befehle in Terminal Master ausführen'
                          : 'Konfigurierte externe Terminal-App verwenden',
                    ),
                    value: _useIntegratedTerminal,
                    onChanged: _isExecuting
                        ? null
                        : (value) =>
                              setState(() => _useIntegratedTerminal = value),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                  );
                }

                final command = _commands[index];
                return CheckboxListTile(
                  title: Text(command.title),
                  subtitle: Text(command.description),
                  value: _selectedIndexes.contains(index),
                  onChanged: _isExecuting
                      ? null
                      : (bool? selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedIndexes.add(index);
                            } else {
                              _selectedIndexes.remove(index);
                            }
                          });
                        },
                  secondary: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
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
                        onPressed: _isExecuting || _isMutating
                            ? null
                            : () => _deleteCommand(index),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.play_arrow),
        label: Text(
          _isExecuting
              ? 'Wird vorbereitet...'
              : _useIntegratedTerminal
              ? 'Ins Terminal einfügen'
              : 'Ausführen',
        ),
        onPressed: _selectedIndexes.isEmpty || _isExecuting
            ? null
            : _executeSelected,
      ),
    );
  }
}
