import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../utils/settings_loader.dart';
import '../widgets/terminal_panel.dart';

/// Native-language label for each supported code. Language names are shown in
/// their own language by convention, so these are deliberately not localized.
const Map<String, String> languageDisplayNames = {
  'en': 'English',
  'de': 'Deutsch',
};

class SettingsPage extends StatefulWidget {
  final String configDirectoryPath;
  final String yamlDirectoryPath;
  final Future<void> Function(String profileId)? saveDefaultProfile;
  final Future<void> Function(String path)? saveYamlDirectoryPath;
  final Future<String?> Function()? selectYamlDirectory;
  final ValueChanged<String>? onYamlDirectoryChanged;

  /// `null` follows the operating system locale.
  final String? languageCode;
  final Future<void> Function(String? code)? saveLanguage;
  final ValueChanged<String?>? onLanguageChanged;

  const SettingsPage({
    super.key,
    required this.configDirectoryPath,
    required this.yamlDirectoryPath,
    this.saveDefaultProfile,
    this.saveYamlDirectoryPath,
    this.selectYamlDirectory,
    this.onYamlDirectoryChanged,
    this.languageCode,
    this.saveLanguage,
    this.onLanguageChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isSaving = false;
  late String _yamlDirectoryPath;
  late String? _languageCode;

  @override
  void initState() {
    super.initState();
    _yamlDirectoryPath = widget.yamlDirectoryPath;
    _languageCode = widget.languageCode;
  }

  Future<void> _selectProfile(String profileId) async {
    final l10n = AppLocalizations.of(context);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsDefaultShellSaved)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsDefaultShellSaveFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectLanguage(String? code) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isSaving = true);
    try {
      final saveLanguage =
          widget.saveLanguage ??
          (code) =>
              SettingsLoader.saveLanguage(widget.configDirectoryPath, code);
      await saveLanguage(code);
      if (!mounted) return;
      setState(() => _languageCode = code);
      widget.onLanguageChanged?.call(code);
      // Deferred by one frame on purpose: the locale change above only takes
      // effect on the next build, and the confirmation should already speak
      // the newly selected language rather than the previous one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).settingsLanguageSaved),
          ),
        );
      });
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsLanguageSaveFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectYamlDirectory() async {
    final l10n = AppLocalizations.of(context);
    try {
      final path =
          await (widget.selectYamlDirectory?.call() ??
              FilePicker.platform.getDirectoryPath(
                dialogTitle: l10n.settingsSelectYamlDirectory,
                initialDirectory: _yamlDirectoryPath,
              ));
      if (path == null || !mounted) return;
      if (!Directory(path).existsSync()) {
        throw FileSystemException(l10n.settingsYamlDirectoryMissing);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsYamlDirectorySaved)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsYamlDirectorySaveFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sectionStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(color: TerminalMasterColors.yellow);
    final controller = TerminalPanelScope.of(context);
    return Scaffold(
      backgroundColor: TerminalMasterColors.surface,
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l10n.settingsSectionTerminal, style: sectionStyle),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('default-shell-profile'),
            initialValue: controller.defaultProfile.id,
            decoration: InputDecoration(
              labelText: l10n.settingsDefaultShellLabel,
              helperText: l10n.settingsDefaultShellHelper,
              border: const OutlineInputBorder(),
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
          Text(l10n.settingsSectionLanguage, style: sectionStyle),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('ui-language'),
            initialValue: _languageCode ?? SettingsLoader.systemLanguage,
            decoration: InputDecoration(
              labelText: l10n.settingsLanguageLabel,
              helperText: l10n.settingsLanguageHelper,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: SettingsLoader.systemLanguage,
                child: Text(l10n.settingsLanguageSystem),
              ),
              for (final code in SettingsLoader.supportedLanguageCodes)
                DropdownMenuItem(
                  value: code,
                  child: Text(languageDisplayNames[code] ?? code),
                ),
            ],
            onChanged: _isSaving
                ? null
                : (value) {
                    if (value == null) return;
                    _selectLanguage(
                      value == SettingsLoader.systemLanguage ? null : value,
                    );
                  },
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),
          Text(l10n.settingsSectionCommandBuilder, style: sectionStyle),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.settingsYamlDirectoryLabel,
              helperText: l10n.settingsYamlDirectoryHelper,
              border: const OutlineInputBorder(),
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
                  tooltip: l10n.settingsSelectYamlDirectory,
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
