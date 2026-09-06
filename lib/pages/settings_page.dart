import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/settings_loader.dart';
import '../widgets/terminal_panel.dart';

class SettingsPage extends StatefulWidget {
  final String configDirectoryPath;
  final Future<void> Function(String profileId)? saveDefaultProfile;

  const SettingsPage({
    super.key,
    required this.configDirectoryPath,
    this.saveDefaultProfile,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isSaving = false;

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
          if (_isSaving) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
