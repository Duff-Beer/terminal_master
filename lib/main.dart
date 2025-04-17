import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import 'command_generator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appSupportDir = await getApplicationSupportDirectory();
  final terminalMasterDir = Directory('${appSupportDir.path}/terminal-master');

  if (!terminalMasterDir.existsSync()) {
    terminalMasterDir.createSync(recursive: true);
  }

  // Pfad mit Tilde darstellen
  String displayPath = terminalMasterDir.path;
  final homeDir = Platform.environment['HOME'];
  if (homeDir != null && displayPath.startsWith(homeDir)) {
    displayPath = displayPath.replaceFirst(homeDir, '~');
  }

  runApp(MyApp(
      configDirectoryPath: terminalMasterDir.path, displayPath: displayPath));
}

class MyApp extends StatelessWidget {
  final String configDirectoryPath;
  final String displayPath;

  const MyApp(
      {super.key,
      required this.configDirectoryPath,
      required this.displayPath});

  @override
  Widget build(BuildContext context) {
    // Erstellen eines dunklen Themes mit grünen Akzenten
    final theme = ThemeData(
      brightness: Brightness.dark,
      // Entfernen Sie primaryColor, wenn Sie colorScheme verwenden
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      fontFamily: 'Courier', // Monospaced Font
      iconTheme: const IconThemeData(color: Colors.green),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.green,
          fontFamily: 'Courier',
          fontSize: 20,
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.green, fontFamily: 'Courier'),
        bodySmall: TextStyle(color: Colors.green, fontFamily: 'Courier'),
        bodyLarge: TextStyle(color: Colors.green, fontFamily: 'Courier'),
        titleMedium: TextStyle(color: Colors.green, fontFamily: 'Courier'),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Colors.black,
        filled: true,
        hintStyle: const TextStyle(color: Colors.green),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green, width: 2),
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: Colors.green,
        secondary: Colors.green,
        background: Colors.black,
        surface: Colors.black,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onBackground: Colors.green,
        onSurface: Colors.green,
      ),
    );

    return MaterialApp(
      theme: theme,
      home: MainPage(
          configDirectoryPath: configDirectoryPath, displayPath: displayPath),
    );
  }
}

class ConfigItem {
  final String command;
  final String description;
  final String filePath;

  ConfigItem(
      {required this.command,
      required this.description,
      required this.filePath});
}

class MainPage extends StatefulWidget {
  final String configDirectoryPath;
  final String displayPath;

  const MainPage(
      {super.key,
      required this.configDirectoryPath,
      required this.displayPath});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  List<ConfigItem> _configItems = [];
  List<ConfigItem> _filteredItems = [];
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfigFiles();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _filterItems();
    });
  }

  void _filterItems() {
    if (_searchQuery.isEmpty) {
      _filteredItems = List.from(_configItems);
    } else {
      _filteredItems = _configItems
          .where((item) => item.command.toLowerCase().contains(_searchQuery))
          .toList();
    }
  }

  void _loadConfigFiles() {
    final directory = Directory(widget.configDirectoryPath);

    try {
      if (!directory.existsSync()) {
        setState(() {
          _configItems = [];
          _filteredItems = [];
        });
        return;
      }

      final files = directory.listSync().where(
          (file) => file.path.endsWith('.yaml') || file.path.endsWith('.yml'));

      List<ConfigItem> tempList = [];
      for (var file in files) {
        try {
          final yamlFile = File(file.path);
          final yamlString = yamlFile.readAsStringSync();
          final config = loadYaml(yamlString);

          if (config == null || config['command'] == null) {
            continue;
          }

          final command = config['command'].toString();
          final description =
              config['description']?.toString() ?? 'No description available';

          tempList.add(ConfigItem(
            command: command,
            description: description,
            filePath: file.path,
          ));
        } catch (e) {
          print('Invalid config file: ${file.path}, Error: $e');
        }
      }

      // Alphabetisch sortieren
      tempList.sort((a, b) => a.command.compareTo(b.command));

      setState(() {
        _configItems = tempList;
        _filterItems();
      });
    } catch (e) {
      print('Error reading directory: $e');
      setState(() {
        _configItems = [];
        _filteredItems = [];
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Zugriff auf das Verzeichnis: $e'),
          ),
        );
      });
    }
  }

  Future<void> _openFinder() async {
    final directory = Directory(widget.configDirectoryPath);
    if (directory.existsSync()) {
      await Process.run('open', [directory.path]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verzeichnis nicht gefunden.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hintergrundanpassung und Gesamtästhetik einer "Hacker-Konsole"
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal Command Generator'),
        // Suchfeld in der AppBar
        actions: [
          // Suchen...
          Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.green),
              cursorColor: Colors.green,
              decoration: InputDecoration(
                hintText: 'Suchen...',
                hintStyle: const TextStyle(color: Colors.green),
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Im Finder anzeigen',
            onPressed: _openFinder,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Erneuern',
            onPressed: _loadConfigFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Config Directory: ${widget.displayPath}'),
          ),
          Expanded(
            child: _filteredItems.isEmpty
                ? const Center(child: Text('No config files found'))
                : ListView.builder(
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return ListTile(
                        title: Text(item.command),
                        subtitle: Text(item.description),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CommandGeneratorPage(
                                configPath: item.filePath,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
