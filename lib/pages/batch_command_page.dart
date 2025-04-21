import 'dart:io';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import '../services/command_executor.dart';
import '../widgets/output_dialog.dart';

class BatchCommandPage extends StatefulWidget {
  final String filePath;

  const BatchCommandPage({super.key, required this.filePath});

  @override
  State<BatchCommandPage> createState() => _BatchCommandPageState();
}

class _BatchCommandPageState extends State<BatchCommandPage> {
  List<Map<String, String>> _commands = [];
  final Set<int> _selectedIndexes = {};

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
    for (var i in _selectedIndexes) {
      final cmd = _commands[i]['command'] ?? '';
      if (cmd.isNotEmpty) {
        try {
          await CommandExecutor.executeInTerminal(cmd, true);
        } catch (e) {
          showOutputDialog(
              context, 'Fehler bei Befehl ${_commands[i]['title']}: $e');
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
          : ListView.builder(
              itemCount: _commands.length,
              itemBuilder: (context, index) {
                final command = _commands[index];
                return CheckboxListTile(
                  title: Text(command['title'] ?? 'Unbenannt'),
                  subtitle: Text(command['description'] ?? ''),
                  value: _selectedIndexes.contains(index),
                  onChanged: (bool? selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedIndexes.add(index);
                      } else {
                        _selectedIndexes.remove(index);
                      }
                    });
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.play_arrow),
        label: const Text('Ausführen'),
        onPressed: _selectedIndexes.isEmpty ? null : _executeSelected,
      ),
    );
  }
}
