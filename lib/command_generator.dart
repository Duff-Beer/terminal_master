import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:process_run/process_run.dart'; // Neu hinzugefügt

class CommandGeneratorPage extends StatefulWidget {
  final String configPath;

  const CommandGeneratorPage({super.key, required this.configPath});

  @override
  State<CommandGeneratorPage> createState() => _CommandGeneratorPageState();
}

class _CommandGeneratorPageState extends State<CommandGeneratorPage> {
  Map<String, dynamic>? commandConfig;
  Map<String, dynamic> selectedParameters = {};

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  Map<String, dynamic> _convertYamlMap(YamlMap yamlMap) {
    final map = <String, dynamic>{};
    yamlMap.forEach((key, value) {
      if (value is YamlMap) {
        map[key.toString()] = _convertYamlMap(value);
      } else if (value is YamlList) {
        map[key.toString()] = value
            .map((item) => item is YamlMap ? _convertYamlMap(item) : item)
            .toList();
      } else {
        map[key.toString()] = value;
      }
    });
    return map;
  }

  void _loadConfiguration() {
    final file = File(widget.configPath);
    final yamlString = file.readAsStringSync();
    setState(() {
      commandConfig = _convertYamlMap(loadYaml(yamlString));
    });
  }

  void _validateParameters() {
    if (commandConfig == null) return;

    for (var param in commandConfig!['parameters']) {
      String name = param['name'];

      // Abhängigkeiten prüfen
      if (param.containsKey('depends_on')) {
        for (var dependency in param['depends_on']) {
          if (selectedParameters[name] != null &&
              selectedParameters[dependency] == null) {
            throw Exception(
                'Parameter "$name" erfordert, dass "$dependency" gesetzt ist.');
          }
        }
      }

      // Konflikte prüfen
      if (param.containsKey('conflicts_with')) {
        for (var conflict in param['conflicts_with']) {
          if (selectedParameters[name] != null &&
              selectedParameters[conflict] != null) {
            throw Exception(
                'Parameter "$name" kann nicht mit "$conflict" verwendet werden.');
          }
        }
      }

      // Unterschiedlichkeit prüfen
      if (param.containsKey('must_differ') && param['must_differ'] == true) {
        if (selectedParameters[name] ==
            selectedParameters[param['depends_on']?.first]) {
          throw Exception(
              'Parameter "$name" muss sich von seiner Abhängigkeit unterscheiden.');
        }
      }
    }
  }

  Widget _buildParameterInput(Map<String, dynamic> param) {
    switch (param['type']) {
      case 'filepath':
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: TextEditingController(
                  text: selectedParameters[param['name']] ?? '',
                ),
                decoration: InputDecoration(
                  labelText: param['name'],
                  hintText: param['description'],
                ),
                onChanged: (value) {
                  selectedParameters[param['name']] = value;
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: () async {
                String? selectedPath;
                if (param['mode'] == 'directory') {
                  selectedPath = await FilePicker.platform.getDirectoryPath();
                } else {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles();
                  selectedPath = result?.files.single.path;
                }

                if (selectedPath != null) {
                  setState(() {
                    selectedParameters[param['name']] = selectedPath;
                  });
                }
              },
            )
          ],
        );

      case 'boolean':
        return SwitchListTile(
          title: Text(param['name']),
          subtitle: Text(param['description']),
          value: selectedParameters[param['name']] ?? false,
          onChanged: (bool value) {
            setState(() {
              selectedParameters[param['name']] = value;
            });
          },
        );

      case 'options':
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: param['name'],
            helperText: param['description'],
          ),
          items: (param['options'] as List)
              .map<DropdownMenuItem<String>>((option) {
            return DropdownMenuItem<String>(
              value: option['value'],
              child: Text('${option['value']}: ${option['description']}'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedParameters[param['name']] = value;
            });
          },
        );

      case 'button':
        return ElevatedButton(
          onPressed: () async {
            await _executeCommandWithShell(param);
          },
          child: Text(param['label'] ?? param['name']),
        );

      default:
        return TextField(
          decoration: InputDecoration(
            labelText: param['name'],
            hintText: param['description'],
          ),
          onChanged: (value) {
            selectedParameters[param['name']] = value;
          },
        );
    }
  }

  Future<void> _executeCommandWithShell(Map<String, dynamic> param) async {
    var shell = Shell();

    String executable = param['executable'];

    try {
      var result = await shell.run(executable);
      _showOutputDialog(result.outText);
    } catch (e) {
      _showOutputDialog('Error: $e');
    }
  }

  Future<void> _showOutputDialog(String output) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Command Output'),
          content: SingleChildScrollView(
            child: Text(output),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Schließen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String _generateCommand() {
    if (commandConfig == null) return '';

    try {
      _validateParameters();
    } catch (e) {
      _showOutputDialog('Error: ${e.toString()}');
      return '';
    }

    final raw = commandConfig!['command'].toString();
    String command = raw.replaceAll('_', ' ');
    // Sortiere Parameter nach der Reihenfolge
    List<dynamic> sortedParameters = List.from(commandConfig!['parameters']);
    sortedParameters
        .sort((a, b) => (a['order'] ?? 1000).compareTo(b['order'] ?? 1000));

    String prefix = '';

    // Generiere Prefix für Parameter mit order: 0
    for (var param in sortedParameters) {
      if (param['order'] == 0) {
        var value = selectedParameters[param['name']];
        if (value != null && value is bool && value == true) {
          prefix += '${param['flag']} ';
        } else if (value != null && value is String && value.isNotEmpty) {
          prefix += '${param['prefix'] ?? ''}$value${param['suffix'] ?? ''} ';
        }
      }
    }

    // Füge Prefix vor dem eigentlichen Command hinzu
    command = '$prefix$command';

    // Generiere den Rest des Befehls
    for (var param in sortedParameters) {
      if (param['order'] == 0) {
        continue; // Überspringe bereits verarbeitete Parameter
      }

      // Überspringe Button-Parameter bei der Befehlserstellung
      if (param['type'] == 'button') continue;

      var value = selectedParameters[param['name']];
      if (param['required'] == true && (value == null || value == '')) {
        _showOutputDialog('Required parameter ${param['name']} is missing');
        return '';
      }

      if (value != null) {
        String formattedValue = value.toString();

        // Füge Prefix und Suffix hinzu
        if (param.containsKey('prefix')) {
          formattedValue = '${param['prefix']}$formattedValue';
        }
        if (param.containsKey('suffix')) {
          formattedValue = '$formattedValue${param['suffix']}';
        }

        // Füge den formatierten Wert zum Befehl hinzu
        if (param['type'] == 'boolean' && value == true) {
          command += ' ${param['flag']}';
        } else if (param['type'] == 'options') {
          command += ' ${param['flag']} $formattedValue';
        } else if (param['type'] != 'boolean') {
          command += ' $formattedValue';
        }
      }
    }

    return command.trim();
  }

  Future<void> _executeCommand(String command) async {
    if (command.isEmpty) return;
    try {
      List<String> parts = command.split(' ');
      String executable = parts.first;
      List<String> arguments = parts.skip(1).toList();

      // Verwenden Sie runExecutableArguments statt run
      final result = await runExecutableArguments(executable, arguments);
      _showOutputDialog(result.stdout.toString());
    } catch (e) {
      _showOutputDialog('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (commandConfig == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(commandConfig!['command'].toUpperCase()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            commandConfig!['description'],
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...commandConfig!['parameters']
              .map<Widget>((param) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: _buildParameterInput(param),
                  ))
              .toList(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              String command = _generateCommand();
              if (command.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: command));
                _showOutputDialog(
                    'Command in die Zwischenablage kopiert:\n$command');
              }
            },
            child: const Text('Generate Command'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              String command = _generateCommand();
              await _executeCommand(command);
            },
            child: const Text('Execute Command'),
          ),
          const SizedBox(height: 16),
          Text(
            commandConfig!['help_text'] ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
