import 'dart:io';

import 'package:flutter/material.dart';
import '../models/batch_command.dart';
import '../services/command_executor.dart';
import '../services/command_risk_assessor.dart';
import '../services/terminal_backend.dart';
import '../utils/config_loader.dart';
import '../widgets/command_confirmation_dialog.dart';
import '../widgets/output_dialog.dart';
import 'integrated_terminal_page.dart';
import 'package:flutter/services.dart';

class BatchCommandPage extends StatefulWidget {
  final String filePath;
  final TerminalBackendFactory terminalBackendFactory;

  const BatchCommandPage({
    super.key,
    required this.filePath,
    this.terminalBackendFactory = unavailableTerminalBackendFactory,
  });

  @override
  State<BatchCommandPage> createState() => _BatchCommandPageState();
}

class _BatchCommandPageState extends State<BatchCommandPage> {
  List<BatchCommand> _commands = [];
  final Set<int> _selectedIndexes = {};
  bool _runInSameTerminal = false;
  bool _useIntegratedTerminal = true;
  bool _isExecuting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadBatchFile();
  }

  void _loadBatchFile() {
    try {
      _commands = ConfigLoader.loadBatchConfig(widget.filePath).commands;
    } on Object catch (error) {
      _loadError = error.toString();
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
      final approved = await showCommandConfirmationDialog(
        context,
        commands: commands,
        assessment: CommandRiskAssessor.assessRawCommands(commands),
      );
      if (!mounted || !approved) return;

      if (_useIntegratedTerminal) {
        final terminalCommands = _runInSameTerminal
            ? [commands.join(' && ')]
            : commands;
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => IntegratedTerminalPage(
              initialCommands: terminalCommands,
              backendFactory: widget.terminalBackendFactory,
            ),
          ),
        );
      } else if (_runInSameTerminal) {
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
      appBar: AppBar(title: const Text('Batch Commands')),
      body: _commands.isEmpty
          ? const Center(child: Text('Keine Befehle gefunden.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _commands.length + 2,
              itemBuilder: (context, index) {
                if (index == _commands.length) {
                  return SwitchListTile(
                    title: const Text('Im selben Terminal ausführen'),
                    subtitle: Text(
                      _runInSameTerminal
                          ? 'Mit && verknüpfen und beim ersten Fehler stoppen'
                          : _useIntegratedTerminal
                          ? Platform.isWindows
                                ? 'In getrennten Tabs; Start beim ersten Öffnen'
                                : 'Parallel in getrennten Terminal-Tabs starten'
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
                  secondary: IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Befehl kopieren',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: command.command));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Befehl in die Zwischenablage kopiert'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.play_arrow),
        label: Text(_isExecuting ? 'Wird gestartet...' : 'Ausführen'),
        onPressed: _selectedIndexes.isEmpty || _isExecuting
            ? null
            : _executeSelected,
      ),
    );
  }
}
