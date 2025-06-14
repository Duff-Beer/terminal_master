import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/settings_loader.dart';
import '../models/config_item.dart';
import '../utils/config_loader.dart';
import '../widgets/config_tile.dart';
import 'command_generator_page.dart';
import 'batch_command_page.dart';
import 'package:flutter/services.dart';

class MainPage extends StatefulWidget {
  final String configDirectoryPath;
  final String displayPath;

  const MainPage({
    super.key,
    required this.configDirectoryPath,
    required this.displayPath,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late List<ConfigItem> _all;
  late List<ConfigItem> _filtered;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfigs();
    _controller.addListener(_onSearch);
  }

  void _loadConfigs() {
    _all = ConfigLoader.loadConfigs(widget.configDirectoryPath);
    _filtered = List.from(_all);
    setState(() {});
  }

  void _onSearch() {
    final q = _controller.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_all)
          : _all.where((c) => c.command.toLowerCase().contains(q)).toList();
    });
  }

  void _openDirectory() async {
    final directory = Directory(widget.configDirectoryPath);
    if (directory.existsSync()) {
      await Process.run(SettingsLoader.fileManagerCommand, [directory.path]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verzeichnis nicht gefunden.')),
      );
      return;
    }

    try {
      if (Platform.isMacOS) {
        await Process.run('open', [directory.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [directory.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [directory.path]);
      } else {
        throw UnsupportedError(
            'Öffnen des Verzeichnisses auf dieser Plattform nicht unterstützt');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Öffnen des Verzeichnisses: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearch);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal Command Generator'),
        actions: [
          SizedBox(
            width: 200,
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.green),
              cursorColor: Colors.green,
              decoration: const InputDecoration(
                hintText: 'Suchen...',
                hintStyle: TextStyle(color: Colors.green),
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Im Finder anzeigen',
            onPressed: _openDirectory,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Erneuern',
            onPressed: _loadConfigs,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.displayPath));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Pfad in die Zwischenablage kopiert')),
                );
              },
              child: Text(
                'Config Directory: ${widget.displayPath}',
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('No config files found'))
                : ListView(
                    children: _buildMenuItems(),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems() {
    final Map<String, List<ConfigItem>> prefixGroups = {};
    final List<ConfigItem> ungrouped = [];

    for (var item in _filtered) {
      if (item.command.contains('_')) {
        final prefix = item.command.split('_').first;
        prefixGroups.putIfAbsent(prefix, () => []).add(item);
      } else {
        ungrouped.add(item);
      }
    }

    final Map<String, List<ConfigItem>> groups = {};
    prefixGroups.forEach((prefix, list) {
      if (list.length > 1) {
        groups[prefix] = list;
      } else {
        ungrouped.addAll(list);
      }
    });

    final List<Widget> widgets = [];
    for (var item in ungrouped) {
      widgets.add(
        ConfigTile(
          item: item,
          onTap: () {
            if (item.isBatch) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BatchCommandPage(filePath: item.filePath),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CommandGeneratorPage(configPath: item.filePath),
                ),
              );
            }
          },
        ),
      );
    }
    for (var prefix in groups.keys.toList()..sort()) {
      final items = groups[prefix]!;
      widgets.add(
        ExpansionTile(
          title: Text(prefix.toUpperCase()),
          children: items.map((item) {
            return ConfigTile(
              item: item,
              onTap: () {
                if (item.isBatch) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BatchCommandPage(filePath: item.filePath),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CommandGeneratorPage(configPath: item.filePath),
                    ),
                  );
                }
              },
            );
          }).toList(),
        ),
      );
    }
    return widgets;
  }
}
