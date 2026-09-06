import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/settings_loader.dart';
import '../widgets/terminal_panel.dart';

class SettingsPage extends StatefulWidget {
  final String configDirectoryPath;
  final String yamlDirectoryPath;
  final Future<void> Function(String profileId)? saveDefaultProfile;
  final Future<void> Function(String path)? saveYamlDirectoryPath;
  final Future<String?> Function()? selectYamlDirectory;
  final ValueChanged<String>? onYamlDirectoryChanged;

  const SettingsPage({
    super.key,
    required this.configDirectoryPath,
    required this.yamlDirectoryPath,
    this.saveDefaultProfile,
    this.saveYamlDirectoryPath,
    this.selectYamlDirectory,
    this.onYamlDirectoryChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isSaving = false;
  late String _yamlDirectoryPath;

  @override
  void initState() {
    super.initState();
    _yamlDirectoryPath = widget.yamlDirectoryPath;
  }

  Future<void> _selectProfile(String profileId) async {
    final controller = TerminalPanelScope.of(context);
    setState(() => _isSaving = true);
    try {
      final saveDefaultProfile =
          widget.saveDefaultProfile ??
          (profileId) => SettingsLoader.saveDefaultIntegratedTerminalProfile(
            widget.configDirectoryPath,
            profileId,
          );
      await saveDefaultProfile(profileId);
      if (!mounted) return;
      controller.setDefaultProfile(profileId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Standard-Shell wurde gespeichert.')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Standard-Shell konnte nicht gespeichert werden: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectYamlDirectory() async {
    try {
      final path =
          await (widget.selectYamlDirectory?.call() ??
              FilePicker.platform.getDirectoryPath(
                dialogTitle: 'YAML-Ordner auswählen',
                initialDirectory: _yamlDirectoryPath,
              ));
      if (path == null || !mounted) return;
      if (!Directory(path).existsSync()) {
        throw const FileSystemException(
          'Der ausgewählte Ordner existiert nicht.',
        );
      }
      setState(() => _isSaving = true);
      final saveYamlDirectoryPath =
          widget.saveYamlDirectoryPath ??
          (path) => SettingsLoader.saveYamlDirectoryPath(
            widget.configDirectoryPath,
            path,
          );
      await saveYamlDirectoryPath(path);
      if (!mounted) return;
      setState(() => _yamlDirectoryPath = path);
      widget.onYamlDirectoryChanged?.call(path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Standard-YAML-Ordner wurde gespeichert.'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Standard-YAML-Ordner konnte nicht gespeichert werden: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = TerminalPanelScope.of(context);
    return Scaffold(
      backgroundColor: TerminalMasterColors.surface,
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Terminal',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: TerminalMasterColors.yellow,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('default-shell-profile'),
            initialValue: controller.defaultProfile.id,
            decoration: const InputDecoration(
              labelText: 'Standard-Shell',
              helperText: 'Wird für neue Terminal-Tabs verwendet.',
              border: OutlineInputBorder(),
            ),
            items: controller.profiles
                .map(
                  (profile) => DropdownMenuItem(
                    value: profile.id,
                    child: Text(profile.name),
                  ),
                )
                .toList(),
            onChanged: _isSaving
                ? null
                : (profileId) {
                    if (profileId != null) _selectProfile(profileId);
                  },
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),
          Text(
            'Command Builder',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: TerminalMasterColors.yellow,
            ),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Standard-YAML-Ordner',
              helperText: 'Vorlagen werden aus diesem Ordner geladen.',
              border: OutlineInputBorder(),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _yamlDirectoryPath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  key: const Key('select-yaml-directory'),
                  tooltip: 'YAML-Ordner auswählen',
                  onPressed: _isSaving ? null : _selectYamlDirectory,
                  icon: const Icon(Icons.folder_open_outlined),
                ),
              ],
            ),
          ),
          if (_isSaving) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
