// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDescription => 'Description';

  @override
  String buildFailurePipelineNeedsCommand(String parameter) {
    return 'Pipeline “$parameter” needs a command.';
  }

  @override
  String get buildFailureCommandIsEmpty => 'The command to run is empty.';

  @override
  String get buildFailureInvalidButtonAction => 'Invalid button action.';

  @override
  String buildFailureRequiredParameterMissing(String parameter) {
    return 'Required parameter “$parameter” is missing.';
  }

  @override
  String buildFailureParameterRequiresOther(String parameter, String other) {
    return 'Parameter “$parameter” requires “$other”.';
  }

  @override
  String buildFailureParameterConflictsWithOther(
    String parameter,
    String other,
  ) {
    return 'Parameter “$parameter” cannot be used together with “$other”.';
  }

  @override
  String buildFailureParameterMustDifferFromOther(
    String parameter,
    String other,
  ) {
    return 'Parameter “$parameter” must differ from “$other”.';
  }

  @override
  String buildFailureInvalidOptionValue(String parameter) {
    return 'Parameter “$parameter” contains an invalid option value.';
  }

  @override
  String get buildFailureDdInputEqualsOutput =>
      'The input and output of dd must differ.';

  @override
  String buildFailureMultipleValuesNotAttachable(String parameter) {
    return 'Parameter “$parameter” cannot attach multiple values directly to one flag.';
  }

  @override
  String buildFailureInvalidConfigurationValue(String detail) {
    return 'Invalid configuration value: $detail';
  }

  @override
  String buildFailureParameterMustBeList(String parameter) {
    return 'Parameter “$parameter” must contain a list.';
  }

  @override
  String get buildFailureControlCharactersNotAllowed =>
      'Command arguments must not contain control characters.';

  @override
  String get buildFailureUnsafeWindowsCharacter =>
      'The Windows shell cannot safely handle this character in input values.';

  @override
  String get optionStoreValueAndDescriptionRequired =>
      'Value and description must not be empty.';

  @override
  String get optionStoreControlCharactersNotAllowed =>
      'Value and description must not contain control characters.';

  @override
  String get optionStoreFileChangedMeanwhile =>
      'The YAML file changed in the meantime. Open it again.';

  @override
  String optionStoreDuplicateOptionValue(String value) {
    return 'The option value “$value” already exists.';
  }

  @override
  String get optionStoreNewEntryNotValid =>
      'The new entry could not be validated.';

  @override
  String optionStoreOptionValueNotFound(String value) {
    return 'The option value “$value” was not found.';
  }

  @override
  String get optionStoreLastOptionCannotBeDeleted =>
      'The last option value cannot be deleted.';

  @override
  String get optionStoreUnsupportedOptionListFormat =>
      'The option list uses an unsupported YAML format.';

  @override
  String get optionStoreEntryNotFullyDeleted =>
      'The entry could not be deleted completely.';

  @override
  String get optionStoreInvalidYamlRoot => 'The YAML root is invalid.';

  @override
  String get optionStoreMissingParameterList =>
      'The parameter list is missing.';

  @override
  String optionStoreOptionsParameterNotFound(String name) {
    return 'The options parameter “$name” was not found.';
  }

  @override
  String get optionStoreMissingOptionList => 'The option list is missing.';

  @override
  String optionStoreMissingField(String field) {
    return 'The field “$field” is missing.';
  }

  @override
  String get batchStoreTitleAndCommandRequired =>
      'Title and command must not be empty.';

  @override
  String get batchStoreUnsupportedCommandListFormat =>
      'The command list uses an unsupported YAML format.';

  @override
  String get batchStoreNewCommandNotValid =>
      'The new command could not be validated.';

  @override
  String get batchStoreCommandToDeleteNotFound =>
      'The command to delete was not found.';

  @override
  String get batchStoreCommandNotFullyDeleted =>
      'The command could not be deleted completely.';

  @override
  String get batchStoreInvalidYamlRoot => 'The YAML root is invalid.';

  @override
  String get batchStoreMissingCommandList => 'The command list is missing.';

  @override
  String get batchStoreFileChangedMeanwhile =>
      'The YAML file changed in the meantime. Open it again.';

  @override
  String batchStoreMissingField(String field) {
    return 'The field “$field” is missing.';
  }

  @override
  String get tabFailureUnknownProfile => 'Unknown profile.';

  @override
  String tabFailureSavedTabsUnreadable(String detail) {
    return 'Saved tabs could not be loaded: $detail';
  }

  @override
  String get tabFailureSshTabsCannotBeSnapshotted =>
      'For security reasons, SSH terminal tabs cannot be stored as a terminal snapshot.';

  @override
  String get tabFailureNameMustNotBeEmpty => 'The name must not be empty.';

  @override
  String get tabFailureSavedTabChangedMeanwhile =>
      'This saved tab changed in the meantime. Open the current version again.';

  @override
  String get tabFailureInvalidTabName => 'Invalid terminal tab name.';

  @override
  String get tabFailureIntegratedTerminalUnavailable =>
      'The built-in terminal is not available.';

  @override
  String tabFailureShellProfileUnavailable(String profile) {
    return 'The shell profile “$profile” is not available.';
  }

  @override
  String get authFailurePassphraseTooLong => 'The key passphrase is too long.';

  @override
  String get authFailurePassphraseRequired =>
      'The private SSH key needs a passphrase.';

  @override
  String get authFailureNoPrivateKeyInFile =>
      'The file does not contain a private SSH key.';

  @override
  String get authFailureInvalidKeyOrPassphrase =>
      'The private SSH key or its passphrase is invalid or unsupported.';

  @override
  String get authFailureInvalidOrUnsupportedKey =>
      'The private SSH key is invalid or unsupported.';

  @override
  String get authFailureKeyFileTooLarge => 'The private key file is too large.';

  @override
  String get authFailureKeyFileUnreadable =>
      'The private key file could not be read.';

  @override
  String get authFailureKeyFileNotUtf8 =>
      'The private key file is not a valid UTF-8 text file.';

  @override
  String authFailureNoStoredPassword(String profile) {
    return 'No password is stored in the keychain for “$profile”.';
  }

  @override
  String authFailureNoPrivateKeyConfigured(String profile) {
    return 'No private key file is configured for “$profile”.';
  }

  @override
  String get backupFailureInvalidAuthenticationInBackup =>
      'The SSH backup contains an invalid authentication type.';

  @override
  String get backupFailureInvalidDataInBackup =>
      'The SSH backup contains invalid data.';

  @override
  String get backupFailureSelectAtLeastOneConnection =>
      'Select at least one SSH connection.';

  @override
  String get backupFailureTooManyConnectionsSelected =>
      'Too many SSH connections selected.';

  @override
  String get backupFailureBackupPasswordTooShort =>
      'The backup password must be at least 12 characters long.';

  @override
  String backupFailureCredentialsNotStored(String profile) {
    return 'The credentials required for “$profile” are not stored.';
  }

  @override
  String get backupFailureFileTooLarge => 'The backup file is too large.';

  @override
  String get backupFailureBackupPasswordMissing =>
      'The backup password is missing.';

  @override
  String get backupFailureInvalidBackupParameters =>
      'Invalid backup parameters.';

  @override
  String get backupFailureInvalidBackupCryptoData =>
      'Invalid backup cryptographic data.';

  @override
  String get backupFailureInvalidBackupContent => 'Invalid backup content.';

  @override
  String get backupFailureInvalidConnectionCount =>
      'The backup contains an invalid number of connections.';

  @override
  String get backupFailureInvalidConnections =>
      'The backup contains invalid connections.';

  @override
  String get backupFailureWrongPasswordOrTampered =>
      'The backup password is wrong or the file was modified.';

  @override
  String get backupFailureConnectionNotExportable =>
      'An SSH connection contains data that cannot be exported.';

  @override
  String get backupFailureUnknownBackupFormat => 'Unknown SSH backup format.';

  @override
  String backupFailureProfileReplacedTwice(String profile) {
    return 'The profile “$profile” cannot be replaced more than once.';
  }

  @override
  String get backupFailureProfileToReplaceNotFound =>
      'An SSH profile to be replaced was not found.';

  @override
  String get backupFailureProfilesChangedDuringImport =>
      'The SSH profiles changed during the import. Start the import again.';

  @override
  String backupFailureImportFailedWithCleanup(String error, String detail) {
    return '$error\nTemporary keychain entries could not be removed either: $detail';
  }

  @override
  String importWarningPreviousPasswordNotRemoved(String detail) {
    return 'A previous password could not be removed: $detail';
  }

  @override
  String get persistedInvalidSavedCommand => 'Invalid saved command.';

  @override
  String get persistedInvalidSavedPane => 'Invalid saved terminal pane.';

  @override
  String get persistedInvalidSavedTab => 'Invalid saved terminal tab.';

  @override
  String get persistedInvalidPaneTopology => 'Invalid pane topology.';

  @override
  String get persistedInvalidSshAuthentication => 'Invalid SSH authentication.';

  @override
  String get persistedInvalidSshProfile => 'Invalid SSH connection profile.';

  @override
  String get persistedInvalidSshHostKey => 'Invalid SSH host key.';

  @override
  String get persistedInvalidSshProfileList => 'Invalid SSH profile list.';

  @override
  String serviceUnsupportedLink(String uri) {
    return 'Unsupported link: $uri';
  }

  @override
  String get serviceLinksNotOpenableOnPlatform =>
      'Links are not opened on this platform.';

  @override
  String get serviceTerminalDetectionUnsupported =>
      'Terminal detection is not supported on this platform.';

  @override
  String get serviceSshProfileNotFound =>
      'The SSH connection profile was not found.';

  @override
  String get sessionFailureSessionNotRunning =>
      'The terminal session is not running.';

  @override
  String get sessionFailureTrackedCommandAlreadyRunning =>
      'A tracked command is already running in this terminal.';

  @override
  String get sessionFailureNulNotAllowed => 'NUL is not allowed.';

  @override
  String get sessionFailureProcessCouldNotBeTerminated =>
      'The terminal process could not be terminated.';

  @override
  String get sessionFailureProcessDidNotExitInTime =>
      'The terminal process did not exit within the time limit.';

  @override
  String get sessionFailureWindowsHomePathNotAscii =>
      'flutter_pty does not currently support Windows user paths containing non-ASCII characters. Use the external terminal for now.';

  @override
  String get sessionFailureShellExecutableEmpty =>
      'The shell program must not be empty.';

  @override
  String get sessionFailureWindowsProfileNotAscii =>
      'flutter_pty currently supports only ASCII characters in built-in shell profiles on Windows. Use the external terminal for now.';

  @override
  String configErrorAt(String file, String field, String reason) {
    return '$file: $field: $reason';
  }

  @override
  String get configReasonMustBeList => 'must be a list';

  @override
  String get configReasonMustBeNonEmptyList => 'must be a non-empty list';

  @override
  String get configReasonMustBeObject => 'must be an object';

  @override
  String get configReasonMustBeText => 'must contain text';

  @override
  String get configReasonMustBeBoolean => 'must be true or false';

  @override
  String get configReasonMustBeInteger => 'must be a whole number';

  @override
  String get configReasonMustBeTextList => 'must be a list of text';

  @override
  String get configReasonMustBeTextOrBoolean => 'must be text, true or false';

  @override
  String get configReasonMustBeFilePickerMode =>
      'must be file, directory or any';

  @override
  String get configReasonMustBeExecutionMode =>
      'must be automatic, before_command, argument or pipeline';

  @override
  String get configReasonMustBeAttachmentMode =>
      'must be automatic, separated or attached';

  @override
  String get configReasonOptionsParameterNeedsEntry =>
      'an options parameter needs at least one entry';

  @override
  String get configReasonButtonNeedsExecutable =>
      'a button needs an executable program';

  @override
  String get configReasonTypeMismatch =>
      'does not have the data type matching the parameter type';

  @override
  String get configReasonNotInOptions => 'is not contained in options';

  @override
  String configReasonDuplicateParameterName(String name) {
    return 'parameter name “$name” appears more than once';
  }

  @override
  String configReasonDuplicateOptionValue(String value) {
    return 'option value “$value” appears more than once';
  }

  @override
  String configReasonUnknownParameterType(String type) {
    return 'unknown parameter type “$type”';
  }

  @override
  String configReasonUnknownParameterReference(String name) {
    return 'refers to unknown parameter “$name”';
  }

  @override
  String configReasonUnknownFields(String fields) {
    return 'contains unknown fields: $fields';
  }

  @override
  String configReasonUnknownGroupFields(String fields) {
    return 'contains unknown group fields: $fields';
  }

  @override
  String get configReasonConditionSelfReference =>
      'a condition must not refer to its own parameter';

  @override
  String configReasonConditionValueTypeMismatch(String name) {
    return 'condition value does not match the type of “$name”';
  }

  @override
  String configReasonConditionValueNotAnOption(String name) {
    return 'condition value is not an option of “$name”';
  }

  @override
  String get configReasonBothAllAndAny =>
      'must not contain all and any at the same time';

  @override
  String get configReasonNeedsAtLeastOneCondition =>
      'must contain at least one condition';

  @override
  String get configReasonOnlyEqualsInOrActive =>
      'may only use equals, in or active';

  @override
  String configReasonUnsupportedSchemaVersion(String version) {
    return 'only version $version is supported';
  }

  @override
  String get configReasonFileNotFound => 'file was not found';

  @override
  String configReasonFileUnreadable(String detail) {
    return 'file could not be read: $detail';
  }

  @override
  String configReasonInvalidYaml(String detail) {
    return 'invalid YAML: $detail';
  }

  @override
  String configItemBatchCommands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commands in this file',
      one: '1 command in this file',
    );
    return '$_temp0';
  }

  @override
  String get configItemNoDescription => 'No description';

  @override
  String configItemLoadError(String file) {
    return 'Error: $file';
  }

  @override
  String get configErrorTitle => 'Configuration error';

  @override
  String get outputTitle => 'Command Output';

  @override
  String generatorAddOptionTitle(String parameter) {
    return 'Add entry to $parameter';
  }

  @override
  String get generatorFieldValue => 'Value';

  @override
  String generatorOptionSaveFailed(String error) {
    return 'Could not save the entry: $error';
  }

  @override
  String generatorOptionDeleteFailed(String error) {
    return 'Could not delete the entry: $error';
  }

  @override
  String generatorBuildFailed(String error) {
    return 'Error: $error';
  }

  @override
  String generatorExecuteFailed(String error) {
    return 'Execution failed: $error';
  }

  @override
  String generatorActionFailed(String error) {
    return 'Action failed: $error';
  }

  @override
  String generatorCommandCopied(String command) {
    return 'Command copied to clipboard:\n$command';
  }

  @override
  String get generatorBuildCommand => 'Build command';

  @override
  String get generatorPreparing => 'Preparing…';

  @override
  String get generatorInsertIntoTerminal => 'Insert into terminal';

  @override
  String get generatorRunCommand => 'Run command';

  @override
  String get generatorIntegratedTerminal => 'Built-in terminal';

  @override
  String get generatorIntegratedTerminalOn =>
      'Run the command inside Terminal Master';

  @override
  String get generatorIntegratedTerminalOff =>
      'Use the configured external terminal app';

  @override
  String get generatorNewExternalTerminal => 'New external terminal';

  @override
  String get pickDirectory => 'Select folder';

  @override
  String get pickFileOrDirectory => 'Select file or folder';

  @override
  String get pickFile => 'Select file';

  @override
  String get listRemoveEntry => 'Remove entry';

  @override
  String get listAddEntry => 'Add another entry';

  @override
  String get riskReasonRmDeletesPermanently =>
      'rm can permanently delete files and directories.';

  @override
  String get riskReasonDdOverwrites =>
      'dd can overwrite files, drives and partitions.';

  @override
  String get riskReasonForceOptionSkipsPrompts =>
      'The force option skips the normal safety prompts.';

  @override
  String get riskReasonElevatedPrivileges =>
      'The command runs with elevated privileges.';

  @override
  String get riskReasonBatchMayDeleteOrOverwrite =>
      'At least one batch command can delete or overwrite data.';

  @override
  String get riskReasonBatchUsesForce =>
      'At least one batch command uses a force option.';

  @override
  String get riskReasonBatchUsesElevatedPrivileges =>
      'At least one batch command uses elevated privileges.';

  @override
  String get confirmTitleStandard => 'Review command';

  @override
  String get confirmTitleElevated => 'Confirm elevated privileges';

  @override
  String get confirmTitleDestructive => 'Confirm destructive command';

  @override
  String get confirmRawConfigWarning =>
      'These commands come straight from a YAML file. Only run them if you trust the file and its contents.';

  @override
  String confirmCommandsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Commands to run',
      one: 'Command to run',
    );
    return '$_temp0';
  }

  @override
  String get confirmAcknowledgement =>
      'I have reviewed the command and understand the risk.';

  @override
  String get confirmRun => 'Run';

  @override
  String get optionsPleaseSelect => 'Please select';

  @override
  String get optionsNotUsed => 'Do not use';

  @override
  String get optionsSearchHint => 'Search value or description';

  @override
  String get optionsNoMatches => 'No matches';

  @override
  String get optionsAddEntry => 'Add entry';

  @override
  String get optionsDeleteEntry => 'Delete entry';

  @override
  String get optionsDeleteTitle => 'Delete entry?';

  @override
  String optionsDeleteMessage(String value) {
    return 'Permanently delete “$value” from the YAML file?';
  }

  @override
  String get mainTitle => 'Command Builder';

  @override
  String get mainSearchHint => 'Search templates';

  @override
  String get mainDirectoryNotFound => 'Folder not found.';

  @override
  String get mainPathCopied => 'Path copied to clipboard';

  @override
  String get mainRevealInFileManager => 'Show in file manager';

  @override
  String get mainRefresh => 'Refresh';

  @override
  String get mainNoConfigFiles => 'No config files found';

  @override
  String get batchTitle => 'Batch Commands';

  @override
  String get batchAddCommand => 'Add batch command';

  @override
  String get batchFieldTitle => 'Title *';

  @override
  String get batchFieldCommand => 'Command *';

  @override
  String get batchUntitled => 'Untitled';

  @override
  String get batchNoCommands => 'No commands found.';

  @override
  String get batchDeleteTitle => 'Delete batch command?';

  @override
  String batchDeleteMessage(String title) {
    return 'Permanently delete “$title”?';
  }

  @override
  String batchSaveFailed(String error) {
    return 'Could not save the command: $error';
  }

  @override
  String batchDeleteFailed(String error) {
    return 'Could not delete the command: $error';
  }

  @override
  String batchInsertFailed(String error) {
    return 'Insert failed: $error';
  }

  @override
  String get batchInsertIntoTerminal => 'Insert into the built-in terminal';

  @override
  String get batchCopyCommand => 'Copy command';

  @override
  String get batchCommandCopied => 'Command copied to clipboard';

  @override
  String get batchDeleteCommand => 'Delete batch command';

  @override
  String get commonName => 'Name';

  @override
  String get commonSave => 'Save';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonPaste => 'Paste';

  @override
  String get commonEdit => 'Edit';

  @override
  String railClose(String tool) {
    return 'Close $tool';
  }

  @override
  String terminalCommandHint(String profile) {
    return 'Commands for $profile …';
  }

  @override
  String get terminalSendToTerminal => 'Send to terminal';

  @override
  String get terminalSearch => 'Search terminal';

  @override
  String get terminalCloseSearch => 'Close search';

  @override
  String get terminalMoreActions => 'More terminal actions';

  @override
  String get terminalRestartSession => 'Restart session';

  @override
  String get terminalCloseTabHint => 'Close tab · right-click for tab actions';

  @override
  String get terminalNewTab => 'New terminal tab';

  @override
  String get terminalOpenSavedTab => 'Open saved terminal tab';

  @override
  String get terminalNoSavedTabs => 'No saved tabs';

  @override
  String get terminalSaveTabTitle => 'Save terminal tab';

  @override
  String get terminalUpdateSavedTab => 'Update saved tab';

  @override
  String get terminalSaveTabNote =>
      'Up to 20 command block commands are stored per pane. Commands may contain sensitive values; terminal output is not stored.';

  @override
  String terminalTabSaved(String name) {
    return 'Terminal tab “$name” was saved.';
  }

  @override
  String terminalSaveFailed(String error) {
    return 'Saving failed: $error';
  }

  @override
  String terminalOpenSnapshotTitle(String name) {
    return 'Open “$name”';
  }

  @override
  String terminalSnapshotSummary(int panes, int commands) {
    return '$panes terminal panes · $commands saved commands';
  }

  @override
  String get terminalPinCommandBar => 'Keep command bar visible';

  @override
  String get terminalUseAutomaticCommandBar =>
      'Automatically show/hide command bar';

  @override
  String get terminalDeleteSavedTab => 'Delete saved state';

  @override
  String get terminalDeleteSavedTabTitle => 'Delete saved state?';

  @override
  String terminalDeleteSavedTabMessage(Object name) {
    return 'Are you sure you want to delete “$name”? Already open terminal sessions will not be affected.';
  }

  @override
  String get terminalRunSavedCommands =>
      'Run saved commands right after opening';

  @override
  String get terminalRunSavedCommandsNote =>
      'The commands run one after another per pane.';

  @override
  String terminalOpenFailed(String error) {
    return 'Opening failed: $error';
  }

  @override
  String terminalAutoRunFailed(String error) {
    return 'Automatic execution failed: $error';
  }

  @override
  String get terminalRestartTitle => 'Restart terminal session?';

  @override
  String get terminalRestartMessage =>
      'The running process is terminated in a controlled manner and the session is restarted immediately. The previous terminal output is reset; unsent commands are preserved.';

  @override
  String get terminalRestart => 'Restart';

  @override
  String terminalRestartFailed(String error) {
    return 'Could not restart the session: $error';
  }

  @override
  String get terminalRenameTab => 'Rename tab';

  @override
  String get terminalSaveTab => 'Save tab';

  @override
  String get terminalRenameTabTitle => 'Rename terminal tab';

  @override
  String get terminalFieldTabName => 'Tab name';

  @override
  String get terminalRename => 'Rename';

  @override
  String get terminalCloseTabTitle => 'Close terminal tab?';

  @override
  String get terminalCloseTabMessage =>
      'All running sessions of this tab will be terminated.';

  @override
  String get terminalCloseTab => 'Close tab';

  @override
  String terminalCloseTabFailed(String error) {
    return 'Could not close the tab: $error';
  }

  @override
  String get terminalTrueColorTooltip =>
      'xterm-256color with 24-bit true color';

  @override
  String get terminalAlternateScreenActive => 'Alternate screen active';

  @override
  String get terminalMouseControlActive => 'Terminal mouse control active';

  @override
  String terminalCommandBlocksCount(int count) {
    return 'Show command history and output ($count)';
  }

  @override
  String get terminalSplitLeftRight => 'Split active window left/right';

  @override
  String get terminalSplitTopBottom => 'Split active window top/bottom';

  @override
  String get terminalClosePane => 'Close window';

  @override
  String get terminalCloseRunningPaneTitle => 'Close running terminal?';

  @override
  String get terminalCloseRunningPaneMessage =>
      'The running session will be terminated.';

  @override
  String get terminalCancel => 'Cancel';

  @override
  String get terminalRestoreSplitView => 'Restore split view';

  @override
  String get terminalMaximizePane => 'Maximize terminal pane';

  @override
  String get terminalDecreaseFontSize => 'Decrease';

  @override
  String get terminalIncreaseFontSize => 'Increase';

  @override
  String get terminalJumpToOutput => 'Jump to latest output';

  @override
  String get terminalNoMatches => '0 matches';

  @override
  String get terminalSearchScrollback => 'Search scrollback';

  @override
  String get terminalPreviousMatch => 'Previous match';

  @override
  String get terminalNextMatch => 'Next match';

  @override
  String get terminalCommandBlocks => 'Command blocks';

  @override
  String get terminalNotWhileRunning =>
      'Not possible while a command is running';

  @override
  String get terminalClearCommandBlocks => 'Clear command blocks';

  @override
  String get terminalNoCommandsYet =>
      'No commands sent through Terminal Master yet.';

  @override
  String get terminalSavedCommands => 'Saved commands';

  @override
  String get terminalFilterAll => 'All';

  @override
  String get terminalFilterCurrentSession => 'Current session';

  @override
  String get terminalRunNow => 'Run now';

  @override
  String get terminalMoreActionsShort => 'More actions';

  @override
  String terminalRunFailed(String error) {
    return 'Execution failed: $error';
  }

  @override
  String terminalSavedCommandSubtitle(String timestamp, String exitCode) {
    return '$timestamp · Exit $exitCode';
  }

  @override
  String terminalOutputTruncated(int limit) {
    final intl.NumberFormat limitNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'Output was truncated after $limitString characters.';
  }

  @override
  String get terminalLabelCommand => 'Command';

  @override
  String get terminalLabelOutput => 'Output';

  @override
  String get terminalExport => 'Export';

  @override
  String get terminalExportCommandBlock => 'Export command block';

  @override
  String terminalExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get terminalStatusRunningBlock => 'Running';

  @override
  String get terminalStatusSucceeded => 'Succeeded (exit 0)';

  @override
  String terminalStatusFailed(String exitCode) {
    return 'Failed (exit $exitCode)';
  }

  @override
  String get terminalStatusInterrupted => 'Interrupted';

  @override
  String get terminalOpenLink => 'Open link';

  @override
  String get terminalSelectAll => 'Select all';

  @override
  String get terminalSearchSelection => 'Search selection';

  @override
  String get terminalClearOutput => 'Clear output';

  @override
  String terminalOpenLinkFailed(String error) {
    return 'Could not open the link: $error';
  }

  @override
  String get terminalPasteMultilineTitle => 'Paste multiline text?';

  @override
  String get terminalPasteMultilineMessage =>
      'Line breaks can execute commands immediately. Check the content before pasting.';

  @override
  String get terminalStatusReady => 'Ready';

  @override
  String get terminalStatusStarting => 'Terminal is starting …';

  @override
  String get terminalStatusActive => 'Terminal running';

  @override
  String terminalStatusExited(String exitCode) {
    return 'Process exited ($exitCode)';
  }

  @override
  String get terminalExitCodeUnknown => 'unknown';

  @override
  String terminalStatusStartFailed(String error) {
    return 'Terminal could not be started: $error';
  }

  @override
  String terminalInfoShell(String name) {
    return 'Shell: $name';
  }

  @override
  String terminalInfoDirectory(String directory) {
    return 'Directory: $directory';
  }

  @override
  String terminalInfoStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get hostKeyUnknownTitle => 'Unknown SSH server';

  @override
  String hostKeyUnknownMessage(
    String endpoint,
    String keyType,
    String fingerprint,
  ) {
    return 'No host key is stored for $endpoint yet.\n\nType: $keyType\nFingerprint: $fingerprint\n\nCompare the fingerprint against a trusted source.';
  }

  @override
  String get hostKeyTrustOnce => 'Trust once';

  @override
  String get hostKeyTrustPermanently => 'Trust permanently';

  @override
  String get hostKeyChangedTitle => 'SSH host key changed';

  @override
  String hostKeyChangedMessage(
    String endpoint,
    String stored,
    String received,
  ) {
    return 'The identity of $endpoint does not match the stored host key. The connection was blocked.\n\nStored: $stored\nReceived: $received';
  }

  @override
  String get sshPageTitle => 'SSH connections';

  @override
  String get sshNoProfilesYet => 'No SSH connections saved yet.';

  @override
  String get sshNoProfilesFound => 'No SSH connections found.';

  @override
  String get sshSearchHint => 'Search SSH connections';

  @override
  String get sshClearSearch => 'Clear search';

  @override
  String get sshAddConnection => 'Add connection';

  @override
  String get sshTest => 'Test';

  @override
  String get sshEdit => 'Edit';

  @override
  String get sshConnect => 'Connect';

  @override
  String get sshSave => 'Save';

  @override
  String get sshAuthenticationKeyLabel => 'Authentication: SSH key';

  @override
  String get sshAuthenticationPasswordLabel => 'Authentication: password';

  @override
  String get sshHostKeyConfirmed => 'Host key confirmed';

  @override
  String get sshHostKeyUnconfirmed => 'Host key not confirmed';

  @override
  String get sshProfileChangedReopen =>
      'The SSH profile changed in the meantime. Open it again.';

  @override
  String get sshProfileChangedDeleteAgain =>
      'The SSH profile changed in the meantime. Delete it again.';

  @override
  String get sshProfilesChangedRetry =>
      'The SSH profiles changed in the meantime. Try again.';

  @override
  String get sshPasswordRequired => 'Please enter an SSH password.';

  @override
  String sshSavedButCredentialCleanupFailed(String error) {
    return 'The profile was saved, but the previous credentials could not be removed from the keychain: $error';
  }

  @override
  String sshSaveFailedWithCleanup(String error, String cleanupError) {
    return 'Could not save the SSH profile: $error\nThe temporary credentials could not be removed either: $cleanupError';
  }

  @override
  String sshSaveFailed(String error) {
    return 'Could not save the SSH profile: $error';
  }

  @override
  String get sshDeleteTitle => 'Delete SSH connection?';

  @override
  String sshDeleteMessage(String name) {
    return 'Delete “$name” including its stored credentials?';
  }

  @override
  String sshDeletedButCredentialCleanupFailed(String error) {
    return 'The profile was deleted, but the credentials could not be removed from the keychain: $error';
  }

  @override
  String sshDeleteFailed(String error) {
    return 'Could not delete the SSH profile: $error';
  }

  @override
  String get sshConnectionSucceeded => 'SSH connection succeeded.';

  @override
  String sshConnectionFailed(String error) {
    return 'SSH connection failed: $error';
  }

  @override
  String get sshExportDialogTitle => 'Export encrypted SSH backup';

  @override
  String get sshImportDialogTitle => 'Import encrypted SSH backup';

  @override
  String get sshImportBackupTooltip => 'Import encrypted backup';

  @override
  String get sshExportBackupTooltip => 'Export encrypted backup';

  @override
  String sshExportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SSH connections exported in encrypted form.',
      one: '1 SSH connection exported in encrypted form.',
    );
    return '$_temp0';
  }

  @override
  String sshExportFailed(String error) {
    return 'SSH export failed: $error';
  }

  @override
  String sshBackupFilePickFailed(String error) {
    return 'Could not choose the backup file: $error';
  }

  @override
  String sshImportSummary(int imported, int replaced, int skipped) {
    return '$imported imported, $replaced replaced, $skipped skipped.';
  }

  @override
  String sshImportFailed(String error) {
    return 'SSH import failed: $error';
  }

  @override
  String get sshBackupFileTooLarge => 'The backup file is too large.';

  @override
  String get sshBackupDialogTitle => 'Encrypted SSH backup';

  @override
  String get sshBackupExportExplanation =>
      'The backup contains the selected connections and their passwords or key passphrases. Private key files are not embedded. The backup is protected with Argon2id and AES-256-GCM.';

  @override
  String get sshBackupPasswordLabel => 'Backup password';

  @override
  String get sshBackupPasswordHelper => 'At least 12 characters';

  @override
  String get sshBackupPasswordTooShort => 'At least 12 characters required.';

  @override
  String get sshBackupPasswordRepeatLabel => 'Repeat backup password';

  @override
  String get sshBackupPasswordMismatch => 'The passwords do not match.';

  @override
  String get sshBackupPasswordNeeded => 'Backup password required.';

  @override
  String get sshBackupDecryptTitle => 'Decrypt SSH backup';

  @override
  String get sshExport => 'Export';

  @override
  String get sshDecrypt => 'Decrypt';

  @override
  String get sshImport => 'Import';

  @override
  String get sshSelectAtLeastOne => 'Select at least one connection.';

  @override
  String get sshImportReviewTitle => 'Review SSH import';

  @override
  String get sshKeyShort => 'SSH key';

  @override
  String get sshPasswordShort => 'Password';

  @override
  String get sshImportDuplicateEndpoint => 'Duplicate endpoint in backup';

  @override
  String get sshImportExistingFound => 'Existing connection found';

  @override
  String get sshImportNewConnection => 'New connection';

  @override
  String get sshImportHostKeyWarning => 'Warning: host key differs';

  @override
  String get sshImportSkip => 'Skip';

  @override
  String get sshImportReplace => 'Replace';

  @override
  String get sshImportNew => 'New';

  @override
  String get sshImportAsCopy => 'As copy';

  @override
  String get sshEditTitle => 'Edit SSH connection';

  @override
  String get sshAddTitle => 'Add SSH connection';

  @override
  String get sshFieldDisplayName => 'Display name';

  @override
  String get sshFieldHost => 'Server address';

  @override
  String get sshFieldPort => 'Port';

  @override
  String get sshFieldUsername => 'Username';

  @override
  String get sshFieldAuthentication => 'Authentication';

  @override
  String get sshPortRange => 'Port must be between 1 and 65535.';

  @override
  String get sshAuthenticationKeyDesktop => 'SSH key (desktop)';

  @override
  String get sshFieldPrivateKeyFile => 'Private key file';

  @override
  String get sshPickKeyFile => 'Select key file';

  @override
  String get sshPrivateKeyRequired => 'Select a private key file.';

  @override
  String get sshClearStoredPassphrase => 'Remove stored passphrase';

  @override
  String get sshKeyPassphraseKeep => 'Key passphrase (leave empty to keep)';

  @override
  String get sshKeyPassphraseOptional => 'Key passphrase (optional)';

  @override
  String get sshPasswordKeep => 'New password (leave empty to keep)';

  @override
  String get sshPasswordLabel => 'Password';

  @override
  String get sshShowPassword => 'Show password';

  @override
  String get sshHidePassword => 'Hide password';

  @override
  String get sshPasswordNotEmpty => 'The password must not be empty.';

  @override
  String get sshCredentialStorageNote =>
      'Passwords and key passphrases are stored exclusively in the operating system keychain. Private keys stay in the selected file.';

  @override
  String sshFieldNotEmpty(String label) {
    return '$label must not be empty.';
  }

  @override
  String sshFieldInvalidControlCharacters(String label) {
    return '$label contains invalid control characters.';
  }

  @override
  String get sshKeyFilesDesktopOnly =>
      'SSH key files are currently only supported on desktop platforms, because mobile file pickers do not provide durably usable paths.';

  @override
  String get sshPickPrivateKeyDialogTitle => 'Select private SSH key file';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionTerminal => 'Terminal';

  @override
  String get settingsDefaultShellLabel => 'Default shell';

  @override
  String get settingsDefaultShellHelper => 'Used for new terminal tabs.';

  @override
  String get settingsDefaultShellSaved => 'Default shell saved.';

  @override
  String settingsDefaultShellSaveFailed(String error) {
    return 'Could not save the default shell: $error';
  }

  @override
  String get settingsSectionCommandBuilder => 'Command Builder';

  @override
  String get settingsYamlDirectoryLabel => 'Default YAML folder';

  @override
  String get settingsYamlDirectoryHelper =>
      'Templates are loaded from this folder.';

  @override
  String get settingsSelectYamlDirectory => 'Select YAML folder';

  @override
  String get settingsYamlDirectoryMissing =>
      'The selected folder does not exist.';

  @override
  String get settingsYamlDirectorySaved => 'Default YAML folder saved.';

  @override
  String settingsYamlDirectorySaveFailed(String error) {
    return 'Could not save the default YAML folder: $error';
  }

  @override
  String get settingsSectionLanguage => 'Language';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsLanguageHelper => 'Takes effect immediately.';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageSaved => 'Language saved.';

  @override
  String settingsLanguageSaveFailed(String error) {
    return 'Could not save the language: $error';
  }
}
