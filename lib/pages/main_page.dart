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
import 'batch_command_page.dart';
import 'package:flutter/services.dart';

class MainPage extends StatefulWidget {
  final String configDirectoryPath;
  final String displayPath;
  final ValueListenable<String>? yamlDirectoryPath;

  const MainPage({
    super.key,
    required this.configDirectoryPath,
    required this.displayPath,
    this.yamlDirectoryPath,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late List<ConfigItem> _all;
  late List<ConfigItem> _filtered;
  final TextEditingController _controller = TextEditingController();

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
    _readConfigs();
  }

  void _readConfigs() {
    _all = ConfigLoader.loadConfigs(
      _directoryPath,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    _filtered = List.from(_all);
  }

  void _reloadConfigs() => setState(_readConfigs);

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
            child: _filtered.isEmpty
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
      widgets.add(ConfigTile(item: item, onTap: () => _openItem(item)));
    }
    for (var prefix in groups.keys.toList()..sort()) {
      final items = groups[prefix]!;
      widgets.add(
        ExpansionTile(
          title: Text(prefix.toUpperCase()),
          children: items.map((item) {
            return ConfigTile(item: item, onTap: () => _openItem(item));
          }).toList(),
        ),
      );
    }
    return widgets;
  }
}
