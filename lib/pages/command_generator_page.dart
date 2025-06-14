import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Für Clipboard
import '../models/command_config.dart';
import '../utils/config_loader.dart';
import '../services/command_executor.dart';
import '../widgets/parameter_input.dart';
import '../widgets/output_dialog.dart';

class CommandGeneratorPage extends StatefulWidget {
  final String configPath;

  const CommandGeneratorPage({super.key, required this.configPath});

  @override
  State<CommandGeneratorPage> createState() => _CommandGeneratorPageState();
}

class _CommandGeneratorPageState extends State<CommandGeneratorPage> {
  bool _openInNewTerminal = true; // Steuerung für Terminal-Modus
  CommandConfig? config;
  final Map<String, dynamic> values = {};

  @override
  void initState() {
    super.initState();
    config = ConfigLoader.loadConfig(widget.configPath);
  }

  void _onParameterChanged(String name, dynamic value) {
    setState(() {
      values[name] = value;
    });
  }

  String _buildCommand() {
    if (config == null) return '';
    // Validierung: Pflicht, Abhängigkeiten, Konflikte, Unterschiedlichkeit
    try {
      for (var p in config!.parameters) {
        var v = values[p.name];
        if (p.required && (v == null || (v is String && v.isEmpty))) {
          throw Exception('Erforderlicher Parameter "${p.name}" fehlt.');
        }
        if (p.dependsOn != null && v != null) {
          for (var dep in p.dependsOn!) {
            if (values[dep] == null) {
              throw Exception('Parameter "${p.name}" erfordert "$dep".');
            }
          }
        }
        if (p.conflictsWith != null && v != null) {
          for (var c in p.conflictsWith!) {
            if (values[c] != null) {
              throw Exception(
                  'Parameter "${p.name}" kann nicht mit "$c" verwendet werden.');
            }
          }
        }
        if (p.mustDiffer && p.dependsOn != null && p.dependsOn!.isNotEmpty) {
          var depValue = values[p.dependsOn!.first];
          if (v != null && v == depValue) {
            throw Exception(
                'Parameter "${p.name}" muss sich von "${p.dependsOn!.first}" unterscheiden.');
          }
        }
      }
    } catch (e) {
      showOutputDialog(context, 'Error: ${e.toString()}');
      return '';
    }

    String raw = config!.command.replaceAll('_', ' ');
    var sorted = List<CommandParameter>.from(config!.parameters)
      ..sort((a, b) => a.order.compareTo(b.order));

    String prefix = '';
    for (var p in sorted.where((p) => p.order == 0)) {
      var v = values[p.name];
      if (p.type == 'boolean' && v == true && p.flag != null) {
        prefix += '${p.flag} ';
      } else if (v != null && v.toString().isNotEmpty) {
        prefix += '${p.prefix ?? ''}$v${p.suffix ?? ''} ';
      }
    }

    String command = '$prefix$raw';

    for (var p in sorted.where((p) => p.order != 0 && p.type != 'button')) {
      var v = values[p.name];
      if (v == null || (v is String && v.isEmpty)) continue;
      if (p.type == 'boolean' && v == true && p.flag != null) {
        command += ' ${p.flag}';
      } else if (p.type == 'options' && p.flag != null) {
        command += ' ${p.flag} ${p.prefix ?? ''}$v${p.suffix ?? ''}';
      } else if (p.type != 'boolean') {
        command += ' ${p.prefix ?? ''}$v${p.suffix ?? ''}';
      }
    }

    return command.trim();
  }

  @override
  Widget build(BuildContext context) {
    if (config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(config!.command.toUpperCase())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(config!.description,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ...config!.parameters.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ParameterInput(
                  param: p,
                  value: values[p.name],
                  onChanged: (v) => _onParameterChanged(p.name, v),
                ),
              )),
          const SizedBox(height: 16),
          // Buttons und Modus-Switch

          ElevatedButton(
            onPressed: () {
              final cmd = _buildCommand();
              if (cmd.isEmpty) return;
              Clipboard.setData(ClipboardData(text: cmd));
              showOutputDialog(
                  context, 'Command in die Zwischenablage kopiert:$cmd');
            },
            child: const Text('Generate Command'),
          ),
          const SizedBox(width: 16),

          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final cmd = _buildCommand();
              if (cmd.isEmpty) return;
              try {
                if (_openInNewTerminal) {
                  await CommandExecutor.executeInTerminal(cmd, true);
                } else {
                  await CommandExecutor.executeInTerminal(cmd, false);
                }
              } catch (e) {
                showOutputDialog(context, 'Fehler beim Ausführen: $e');
              }
            },
            child: const Text('Execute Command'),
          ),
          SwitchListTile(
            title: const Text('New Terminal'),
            value: _openInNewTerminal,
            onChanged: (val) => setState(() => _openInNewTerminal = val),
            contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          ),

          const SizedBox(height: 16),

          if (config!.helpText != null)
            Text(config!.helpText!,
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
