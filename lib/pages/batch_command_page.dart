import 'package:flutter/material.dart';
import '../models/batch_command.dart';
import '../services/command_executor.dart';
import '../services/command_risk_assessor.dart';
import '../utils/config_loader.dart';
import '../widgets/command_confirmation_dialog.dart';
import '../widgets/output_dialog.dart';
import 'package:flutter/services.dart';

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

      if (_runInSameTerminal) {
        final joined = commands.join(' && ');
        await CommandExecutor.executeInTerminal(joined, false);
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
              itemCount: _commands.length + 1,
              itemBuilder: (context, index) {
                if (index == _commands.length) {
                  return SwitchListTile(
                    title: const Text('Im selben Terminal ausführen'),
                    value: _runInSameTerminal,
                    onChanged: _isExecuting
                        ? null
                        : (val) => setState(() => _runInSameTerminal = val),
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
