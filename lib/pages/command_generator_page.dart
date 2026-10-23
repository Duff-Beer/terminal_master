import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/error_presenter.dart';
import '../models/command_config.dart';
import '../models/shell_profile.dart';
import '../services/command_builder.dart';
import '../services/command_executor.dart';
import '../services/command_option_store.dart';
import '../services/command_risk_assessor.dart';
import '../utils/config_loader.dart';
import '../widgets/command_confirmation_dialog.dart';
import '../widgets/output_dialog.dart';
import '../widgets/parameter_input.dart';
import '../widgets/terminal_panel.dart';

class CommandGeneratorPage extends StatefulWidget {
  final String configPath;

  const CommandGeneratorPage({super.key, required this.configPath});

  @override
  State<CommandGeneratorPage> createState() => _CommandGeneratorPageState();
}

class _CommandGeneratorPageState extends State<CommandGeneratorPage> {
  bool _openInNewTerminal = true;
  bool _useIntegratedTerminal = true;
  bool _isExecuting = false;
  CommandConfig? _config;
  Object? _loadError;
  late String _configSource;
  final Map<String, Object?> _values = {};

  CommandShell get _shell {
    if (_useIntegratedTerminal) {
      final controller = TerminalPanelScope.maybeOf(context);
      if (controller != null) {
        return switch (controller.activeProfile.dialect) {
          ShellDialect.posix => CommandShell.posix,
          ShellDialect.windowsCmd => CommandShell.windowsCmd,
          ShellDialect.powerShell => CommandShell.powerShell,
        };
      }
    }
    return Platform.isWindows ? CommandShell.windowsCmd : CommandShell.posix;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState: labels, descriptions and examples come from the YAML file
    // and are resolved per language, so the config is read with the active
    // locale available and re-read when that locale changes.
    final isFirstLoad = _config == null && _loadError == null;
    try {
      _config = ConfigLoader.loadConfig(
        widget.configPath,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      _configSource = File(widget.configPath).readAsStringSync();
      // Only on the first load — a language switch must not discard what the
      // user has already entered.
      if (isFirstLoad) _values.addAll(_config!.defaultValues);
    } on Object catch (error) {
      _loadError = error;
    }
  }

  Future<CommandOption?> _addOption(CommandParameter parameter) async {
    final l10n = AppLocalizations.of(context);
    var enteredValue = '';
    var enteredDescription = '';
    final option = await showDialog<CommandOption>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.generatorAddOptionTitle(parameter.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('new-option-value'),
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.generatorFieldValue),
              onChanged: (value) => enteredValue = value,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('new-option-description'),
              decoration: InputDecoration(labelText: l10n.commonDescription),
              onChanged: (value) => enteredDescription = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-add-option'),
            onPressed: () {
              final value = enteredValue.trim();
              final description = enteredDescription.trim();
              if (value.isEmpty || description.isEmpty) return;
              Navigator.pop(
                context,
                CommandOption(value: value, description: description),
              );
            },
            child: Text(l10n.commonAdd),
          ),
        ],
      ),
    );
    if (option == null || !mounted) return null;
    try {
      await CommandOptionStore.addOption(
        filePath: widget.configPath,
        parameterName: parameter.name,
        option: option,
        expectedContent: _configSource,
      );
      if (!mounted) return null;
      final updatedConfig = ConfigLoader.loadConfig(
        widget.configPath,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      setState(() {
        _config = updatedConfig;
        _configSource = File(widget.configPath).readAsStringSync();
        _values[parameter.name] = option.value;
      });
      return option;
    } on Object catch (error) {
      if (!mounted) return null;
      showOutputDialog(
        context,
        l10n.generatorOptionSaveFailed(localizeError(l10n, error)),
      );
      return null;
    }
  }

  Future<bool> _deleteOption(
    CommandParameter parameter,
    CommandOption option,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await CommandOptionStore.deleteOption(
        filePath: widget.configPath,
        parameterName: parameter.name,
        optionValue: option.value,
        expectedContent: _configSource,
      );
      if (!mounted) return false;
      final updatedConfig = ConfigLoader.loadConfig(
        widget.configPath,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      setState(() {
        _config = updatedConfig;
        _configSource = File(widget.configPath).readAsStringSync();
      });
      return true;
    } on Object catch (error) {
      if (!mounted) return false;
      showOutputDialog(
        context,
        l10n.generatorOptionDeleteFailed(localizeError(l10n, error)),
      );
      return false;
    }
  }

  void _onParameterChanged(String name, Object? value) {
    setState(() => _values[name] = value);
  }

  String? _buildCommand() {
    try {
      return CommandBuilder(
        config: _config!,
        values: _values,
        shell: _shell,
      ).build();
    } on Object catch (error) {
      final l10n = AppLocalizations.of(context);
      showOutputDialog(
        context,
        l10n.generatorBuildFailed(localizeError(l10n, error)),
      );
      return null;
    }
  }

  Future<void> _confirmAndExecute(
    String command,
    CommandRiskAssessment assessment,
    bool alwaysOpenNew,
  ) async {
    if (_isExecuting) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isExecuting = true);
    try {
      if (_useIntegratedTerminal) {
        await TerminalPanelScope.of(context).insertCommand(command);
        if (mounted) ConfigurationPanelScope.maybeOf(context)?.close();
        return;
      }
      final approved = await showCommandConfirmationDialog(
        context,
        commands: [command],
        assessment: assessment,
      );
      if (!mounted || !approved) return;
      await CommandExecutor.executeInTerminal(command, alwaysOpenNew);
    } on Object catch (error) {
      if (!mounted) return;
      showOutputDialog(
        context,
        l10n.generatorExecuteFailed(localizeError(l10n, error)),
      );
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  Future<void> _executeAction(CommandParameter parameter) async {
    final l10n = AppLocalizations.of(context);
    try {
      final command = CommandBuilder(
        config: _config!,
        values: _values,
        shell: _shell,
      ).buildAction(parameter);
      final assessment = CommandRiskAssessor.assessRawCommands([
        command,
      ], containsRawConfiguration: false);
      await _confirmAndExecute(command, assessment, true);
    } on Object catch (error) {
      if (!mounted) return;
      showOutputDialog(
        context,
        l10n.generatorActionFailed(localizeError(l10n, error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loadError case final error?) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.configErrorTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              localizeError(l10n, error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final config = _config!;
    return Scaffold(
      appBar: AppBar(title: Text(config.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            config.description,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...config.parameters
              .where(
                (parameter) => config.isParameterVisible(parameter, _values),
              )
              .map(
                (parameter) => Padding(
                  key: ValueKey(parameter.name),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ParameterInput(
                    key: ValueKey('parameter-${parameter.name}'),
                    param: parameter,
                    value: _values[parameter.name],
                    onChanged: (value) =>
                        _onParameterChanged(parameter.name, value),
                    onAction: parameter.type == CommandParameterType.button
                        ? () => _executeAction(parameter)
                        : null,
                    onAddOption: parameter.type == CommandParameterType.options
                        ? () => _addOption(parameter)
                        : null,
                    onDeleteOption:
                        parameter.type == CommandParameterType.options
                        ? (option) => _deleteOption(parameter, option)
                        : null,
                    required: config.isParameterRequired(parameter, _values),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final command = _buildCommand();
              if (command == null) return;
              await Clipboard.setData(ClipboardData(text: command));
              if (!context.mounted) return;
              showOutputDialog(context, l10n.generatorCommandCopied(command));
            },
            child: Text(l10n.generatorBuildCommand),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isExecuting
                ? null
                : () async {
                    final command = _buildCommand();
                    if (command != null) {
                      final assessment = CommandRiskAssessor.assessConfig(
                        config,
                        _values,
                      );
                      await _confirmAndExecute(
                        command,
                        assessment,
                        _openInNewTerminal,
                      );
                    }
                  },
            child: Text(
              _isExecuting
                  ? l10n.generatorPreparing
                  : _useIntegratedTerminal
                  ? l10n.generatorInsertIntoTerminal
                  : l10n.generatorRunCommand,
            ),
          ),
          SwitchListTile(
            key: const Key('integrated-terminal-toggle'),
            title: Text(l10n.generatorIntegratedTerminal),
            subtitle: Text(
              _useIntegratedTerminal
                  ? l10n.generatorIntegratedTerminalOn
                  : l10n.generatorIntegratedTerminalOff,
            ),
            value: _useIntegratedTerminal,
            onChanged: _isExecuting
                ? null
                : (value) => setState(() => _useIntegratedTerminal = value),
            contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          ),
          if (!_useIntegratedTerminal)
            SwitchListTile(
              title: Text(l10n.generatorNewExternalTerminal),
              value: _openInNewTerminal,
              onChanged: _isExecuting
                  ? null
                  : (value) => setState(() => _openInNewTerminal = value),
              contentPadding: const EdgeInsets.symmetric(horizontal: 28),
            ),
          const SizedBox(height: 16),
          if (config.helpText != null)
            Text(
              config.helpText!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
