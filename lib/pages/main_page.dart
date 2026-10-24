import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/error_presenter.dart';
import '../utils/settings_loader.dart';
import '../models/config_item.dart';
import '../utils/config_loader.dart';
import '../widgets/config_tile.dart';
import '../widgets/output_dialog.dart';
import 'command_generator_page.dart';
import '../services/batch_config_file_service.dart';
import 'batch_command_page.dart';
import 'config_editor_page.dart';
import 'package:flutter/services.dart';

class MainPage extends StatefulWidget {
  final String configDirectoryPath;
  final String displayPath;
  final ValueListenable<String>? yamlDirectoryPath;
  final BatchConfigFileService batchFileService;

  const MainPage({
    super.key,
    required this.configDirectoryPath,
    required this.displayPath,
    this.yamlDirectoryPath,
    this.batchFileService = const BatchConfigFileService(),
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  List<ConfigItem> _all = const [];
  List<ConfigItem> _filtered = const [];
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  String? _loadedDirectory;
  String? _loadedLanguage;
  int _loadGeneration = 0;

  String get _directoryPath =>
      widget.yamlDirectoryPath?.value ?? widget.configDirectoryPath;

  String get _displayPath {
    if (widget.yamlDirectoryPath == null) return widget.displayPath;
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    if (home != null && _directoryPath.startsWith(home)) {
      return _directoryPath.replaceFirst(home, '~');
    }
    return _directoryPath;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearch);
    widget.yamlDirectoryPath?.addListener(_reloadConfigs);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState: the templates' titles and descriptions come from the YAML
    // files and are resolved per language, so the list has to be read with the
    // active locale available — and re-read whenever that locale changes.
    _loadConfigs();
  }

  void _reloadConfigs() => _loadConfigs(force: true);

  Future<void> _loadConfigs({bool force = false}) async {
    final directory = _directoryPath;
    final language = Localizations.localeOf(context).languageCode;
    if (!force &&
        directory == _loadedDirectory &&
        language == _loadedLanguage) {
      return;
    }
    final generation = ++_loadGeneration;
    setState(() => _loading = true);
    late final List<ConfigItem> configs;
    try {
      configs = await ConfigLoader.loadConfigsAsync(
        directory,
        languageCode: language,
      );
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    if (!mounted || generation != _loadGeneration) return;
    final query = _controller.text.trim().toLowerCase();
    setState(() {
      _all = configs;
      _filtered = query.isEmpty
          ? List.of(configs)
          : configs
                .where((item) => item.command.toLowerCase().contains(query))
                .toList();
      _loadedDirectory = directory;
      _loadedLanguage = language;
      _loading = false;
    });
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
    final directory = Directory(_directoryPath);
    if (directory.existsSync()) {
      await Process.run(SettingsLoader.fileManagerCommand, [directory.path]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).mainDirectoryNotFound),
        ),
      );
    }
  }

  Future<void> _showCreateMenu() async {
    final l10n = AppLocalizations.of(context);
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.mainCreateFileType,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              key: const Key('choose-command-config'),
              leading: const Icon(Icons.tune),
              title: Text(l10n.configEditorCreate),
              subtitle: Text(l10n.mainCommandConfigDescription),
              onTap: () => Navigator.pop(context, 'command'),
            ),
            ListTile(
              key: const Key('choose-batch-config'),
              leading: const Icon(Icons.playlist_add),
              title: Text(l10n.batchCreateFile),
              subtitle: Text(l10n.mainBatchConfigDescription),
              onTap: () => Navigator.pop(context, 'batch'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (selection == 'command') {
      await _openEditor();
    } else if (selection == 'batch') {
      await _createBatchFile();
    }
  }

  Future<void> _createBatchFile() async {
    final l10n = AppLocalizations.of(context);
    var name = '';
    final enteredName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.batchCreateFileTitle),
        content: TextField(
          key: const Key('new-batch-file-name'),
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.batchCreateFileName),
          onChanged: (value) => name = value,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-create-batch-file'),
            onPressed: () {
              if (name.trim().isNotEmpty) {
                Navigator.pop(context, name.trim());
              }
            },
            child: Text(l10n.commonAdd),
          ),
        ],
      ),
    );
    if (enteredName == null || !mounted) return;
    try {
      await widget.batchFileService.createEmptyBatchFile(
        directoryPath: _directoryPath,
        name: enteredName,
      );
      if (!mounted) return;
      await _loadConfigs(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.batchFileCreated)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.batchCreateFileFailed('$error'))),
      );
    }
  }

  Future<void> _openEditor([ConfigItem? item]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConfigEditorPage(
          directoryPath: _directoryPath,
          filePath: item?.filePath,
        ),
      ),
    );
    if (saved == true && mounted) await _loadConfigs(force: true);
  }

  void _openItem(ConfigItem item) {
    if (item.error case final error?) {
      showOutputDialog(
        context,
        localizeError(AppLocalizations.of(context), error),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => item.isBatch
            ? BatchCommandPage(filePath: item.filePath)
            : CommandGeneratorPage(configPath: item.filePath),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearch);
    widget.yamlDirectoryPath?.removeListener(_reloadConfigs);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mainTitle)),
      floatingActionButton: FloatingActionButton(
        key: const Key('create-yaml-menu'),
        tooltip: l10n.mainCreateFileType,
        onPressed: _showCreateMenu,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: l10n.mainSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _directoryPath));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.mainPathCopied)),
                      );
                    },
                    child: Text(
                      _displayPath,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_outlined),
                  tooltip: l10n.mainRevealInFileManager,
                  onPressed: _openDirectory,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.mainRefresh,
                  onPressed: _reloadConfigs,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: Icon(
                      Icons.hourglass_empty,
                      key: Key('config-loading'),
                    ),
                  )
                : _filtered.isEmpty
                ? Center(child: Text(l10n.mainNoConfigFiles))
                : ListView(children: _buildMenuItems()),
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
          onTap: () => _openItem(item),
          onEdit: item.error == null && !item.isBatch
              ? () => _openEditor(item)
              : null,
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
              onTap: () => _openItem(item),
              onEdit: item.error == null && !item.isBatch
                  ? () => _openEditor(item)
                  : null,
            );
          }).toList(),
        ),
      );
    }
    return widgets;
  }
}
