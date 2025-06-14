import 'dart:io';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import '../services/command_executor.dart';
import '../widgets/output_dialog.dart';
import 'package:flutter/services.dart';

class BatchCommandPage extends StatefulWidget {
  final String filePath;

  const BatchCommandPage({super.key, required this.filePath});

  @override
  State<BatchCommandPage> createState() => _BatchCommandPageState();
}

class _BatchCommandPageState extends State<BatchCommandPage> {
  List<Map<String, String>> _commands = [];
  final Set<int> _selectedIndexes = {};

  String _previewCommand = '';
  bool _runInSameTerminal = false;
 

  @override
  void initState() {
    super.initState();
    _loadBatchFile();
  }

  void _loadBatchFile() {
    final file = File(widget.filePath);
    if (!file.existsSync()) return;
    final content = file.readAsStringSync();
    final yaml = loadYaml(content);
    final list = yaml['commands'] as YamlList?;
    if (list != null) {
      setState(() {
        _commands = list
            .map((e) => {
                  'title': e['title']?.toString() ?? 'Ohne Titel',
                  'command': e['command']?.toString() ?? '',
                  'description': e['description']?.toString() ?? '',
                })
            .toList();
      });
    }
  }

  Future<void> _executeSelected() async {
    if (_runInSameTerminal) {
      final indexes = _selectedIndexes.toList()..sort();
      final parts = indexes
          .map((i) => _commands[i]['command'] ?? '')
          .where((c) => c.isNotEmpty)
          .toList();
      if (parts.isEmpty) return;
      final joined = parts.join(' && ');
      try {
        await CommandExecutor.executeInTerminal(joined, false);
      } catch (e) {
        if (!mounted) return;
        showOutputDialog(context, 'Fehler beim Ausführen: $e');
      }
    } else {
      for (var i in _selectedIndexes) {
        final cmd = _commands[i]['command'] ?? '';
        if (cmd.isNotEmpty) {
          try {
            await CommandExecutor.executeInTerminal(cmd, true);
          } catch (e) {
            if (!mounted) return;
            showOutputDialog(
                context, 'Fehler bei Befehl ${_commands[i]['title']}: $e');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Commands')),
      body: _commands.isEmpty
          ? const Center(child: Text('Keine Befehle gefunden.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _commands.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _commands.length) {
                        return SwitchListTile(
                          title: const Text('Im selben Terminal ausführen'),
                          value: _runInSameTerminal,
                          onChanged: (val) =>
                              setState(() => _runInSameTerminal = val),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 28),
                        );
                      }

                      final command = _commands[index];
                      return CheckboxListTile(
                        title: Text(command['title'] ?? 'Unbenannt'),
                        subtitle: Text(command['description'] ?? ''),
                        value: _selectedIndexes.contains(index),
                        onChanged: (bool? selected) {
                          setState(() {
                            _previewCommand = command['command'] ?? '';
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
                            Clipboard.setData(
                                ClipboardData(text: command['command'] ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Befehl in die Zwischenablage kopiert')),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (_previewCommand.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: Text(
                      'Vorschau: $_previewCommand',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.play_arrow),
        label: const Text('Ausführen'),
        onPressed: _selectedIndexes.isEmpty ? null : _executeSelected,
      ),
    );
  }
}
