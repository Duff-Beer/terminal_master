import '../models/persisted_data_exception.dart';
import '../services/batch_command_store.dart';
import '../services/command_builder.dart';
import '../services/command_option_store.dart';
import '../services/ssh_authentication.dart';
import '../services/ssh_backup_import_service.dart';
import '../services/ssh_backup_service.dart';
import '../services/service_exception.dart';
import '../services/terminal_session.dart';
import '../services/command_risk_assessor.dart';
import '../utils/config_loader.dart';
import '../widgets/terminal_panel.dart';
import 'app_localizations.dart';

/// Turns errors raised below the UI layer into text in the active language.
///
/// Services, stores and loaders deliberately throw typed errors carrying a
/// reason code instead of a ready-made sentence — they have no `BuildContext`
/// and therefore no locale. This is the single place that resolves those codes,
/// so every dialog and snack bar speaks the selected language.
///
/// Anything unrecognised falls back to `toString()`. That is the escape hatch
/// for platform and plugin exceptions the app does not define itself; it keeps
/// the message useful rather than swallowing it.
String localizeError(AppLocalizations l10n, Object error) => switch (error) {
  ConfigFormatException() => localizeConfigError(l10n, error),
  CommandBuildException() => _buildFailure(l10n, error),
  CommandOptionStoreException() => _optionStoreFailure(l10n, error),
  BatchCommandStoreException() => _batchStoreFailure(l10n, error),
  TerminalTabException() => _tabFailure(l10n, error),
  SshAuthenticationException() => _authFailure(l10n, error),
  SshBackupException() => _backupFailure(l10n, error),
  PersistedDataException() => _persistedProblem(l10n, error),
  ServiceException() => _serviceFailure(l10n, error),
  TerminalSessionException() => _sessionFailure(l10n, error),
  _ => '$error',
};

/// Renders a configuration error as `file: field: reason`.
String localizeConfigError(AppLocalizations l10n, ConfigFormatException error) {
  return l10n.configErrorAt(
    error.filePath,
    error.fieldPath,
    _configReason(l10n, error),
  );
}

String _configReason(AppLocalizations l10n, ConfigFormatException error) {
  // The reasons carrying a detail echo content from the file (a name, a value,
  // a nested parser message); the detail itself is never translated.
  final detail = error.detail ?? '';
  return switch (error.reason) {
    ConfigErrorReason.mustBeList => l10n.configReasonMustBeList,
    ConfigErrorReason.mustBeNonEmptyList => l10n.configReasonMustBeNonEmptyList,
    ConfigErrorReason.mustBeObject => l10n.configReasonMustBeObject,
    ConfigErrorReason.mustBeText => l10n.configReasonMustBeText,
    ConfigErrorReason.mustBeBoolean => l10n.configReasonMustBeBoolean,
    ConfigErrorReason.mustBeInteger => l10n.configReasonMustBeInteger,
    ConfigErrorReason.mustBeTextList => l10n.configReasonMustBeTextList,
    ConfigErrorReason.mustBeTextOrBoolean =>
      l10n.configReasonMustBeTextOrBoolean,
    ConfigErrorReason.mustBeFilePickerMode =>
      l10n.configReasonMustBeFilePickerMode,
    ConfigErrorReason.mustBeExecutionMode =>
      l10n.configReasonMustBeExecutionMode,
    ConfigErrorReason.mustBeAttachmentMode =>
      l10n.configReasonMustBeAttachmentMode,
    ConfigErrorReason.optionsParameterNeedsEntry =>
      l10n.configReasonOptionsParameterNeedsEntry,
    ConfigErrorReason.buttonNeedsExecutable =>
      l10n.configReasonButtonNeedsExecutable,
    ConfigErrorReason.typeMismatch => l10n.configReasonTypeMismatch,
    ConfigErrorReason.notInOptions => l10n.configReasonNotInOptions,
    ConfigErrorReason.duplicateParameterName =>
      l10n.configReasonDuplicateParameterName(detail),
    ConfigErrorReason.duplicateOptionValue =>
      l10n.configReasonDuplicateOptionValue(detail),
    ConfigErrorReason.unknownParameterType =>
      l10n.configReasonUnknownParameterType(detail),
    ConfigErrorReason.unknownParameterReference =>
      l10n.configReasonUnknownParameterReference(detail),
    ConfigErrorReason.unknownFields => l10n.configReasonUnknownFields(detail),
    ConfigErrorReason.unknownGroupFields => l10n.configReasonUnknownGroupFields(
      detail,
    ),
    ConfigErrorReason.conditionSelfReference =>
      l10n.configReasonConditionSelfReference,
    ConfigErrorReason.conditionValueTypeMismatch =>
      l10n.configReasonConditionValueTypeMismatch(detail),
    ConfigErrorReason.conditionValueNotAnOption =>
      l10n.configReasonConditionValueNotAnOption(detail),
    ConfigErrorReason.bothAllAndAny => l10n.configReasonBothAllAndAny,
    ConfigErrorReason.needsAtLeastOneCondition =>
      l10n.configReasonNeedsAtLeastOneCondition,
    ConfigErrorReason.onlyEqualsInOrActive =>
      l10n.configReasonOnlyEqualsInOrActive,
    ConfigErrorReason.unsupportedSchemaVersion =>
      l10n.configReasonUnsupportedSchemaVersion(detail),
    ConfigErrorReason.fileNotFound => l10n.configReasonFileNotFound,
    ConfigErrorReason.fileUnreadable => l10n.configReasonFileUnreadable(detail),
    ConfigErrorReason.invalidYaml => l10n.configReasonInvalidYaml(detail),
  };
}

/// Renders why a command was flagged as risky, for the confirmation dialog.
String localizeRiskReason(AppLocalizations l10n, CommandRiskReason reason) =>
    switch (reason) {
      CommandRiskReason.rmDeletesPermanently =>
        l10n.riskReasonRmDeletesPermanently,
      CommandRiskReason.ddOverwrites => l10n.riskReasonDdOverwrites,
      CommandRiskReason.forceOptionSkipsPrompts =>
        l10n.riskReasonForceOptionSkipsPrompts,
      CommandRiskReason.elevatedPrivileges => l10n.riskReasonElevatedPrivileges,
      CommandRiskReason.batchMayDeleteOrOverwrite =>
        l10n.riskReasonBatchMayDeleteOrOverwrite,
      CommandRiskReason.batchUsesForce => l10n.riskReasonBatchUsesForce,
      CommandRiskReason.batchUsesElevatedPrivileges =>
        l10n.riskReasonBatchUsesElevatedPrivileges,
    };

String _buildFailure(AppLocalizations l10n, CommandBuildException error) {
  final parameter = error.parameter ?? '';
  final detail = error.detail ?? '';
  return switch (error.failure) {
    CommandBuildFailure.pipelineNeedsCommand =>
      l10n.buildFailurePipelineNeedsCommand(parameter),
    CommandBuildFailure.commandIsEmpty => l10n.buildFailureCommandIsEmpty,
    CommandBuildFailure.invalidButtonAction =>
      l10n.buildFailureInvalidButtonAction,
    CommandBuildFailure.requiredParameterMissing =>
      l10n.buildFailureRequiredParameterMissing(parameter),
    CommandBuildFailure.parameterRequiresOther =>
      l10n.buildFailureParameterRequiresOther(parameter, detail),
    CommandBuildFailure.parameterConflictsWithOther =>
      l10n.buildFailureParameterConflictsWithOther(parameter, detail),
    CommandBuildFailure.parameterMustDifferFromOther =>
      l10n.buildFailureParameterMustDifferFromOther(parameter, detail),
    CommandBuildFailure.invalidOptionValue =>
      l10n.buildFailureInvalidOptionValue(parameter),
    CommandBuildFailure.ddInputEqualsOutput =>
      l10n.buildFailureDdInputEqualsOutput,
    CommandBuildFailure.multipleValuesNotAttachable =>
      l10n.buildFailureMultipleValuesNotAttachable(parameter),
    CommandBuildFailure.invalidConfigurationValue =>
      l10n.buildFailureInvalidConfigurationValue(detail),
    CommandBuildFailure.parameterMustBeList =>
      l10n.buildFailureParameterMustBeList(parameter),
    CommandBuildFailure.controlCharactersNotAllowed =>
      l10n.buildFailureControlCharactersNotAllowed,
    CommandBuildFailure.unsafeWindowsCharacter =>
      l10n.buildFailureUnsafeWindowsCharacter,
  };
}

String _optionStoreFailure(
  AppLocalizations l10n,
  CommandOptionStoreException error,
) {
  final detail = error.detail ?? '';
  return switch (error.failure) {
    CommandOptionStoreFailure.valueAndDescriptionRequired =>
      l10n.optionStoreValueAndDescriptionRequired,
    CommandOptionStoreFailure.controlCharactersNotAllowed =>
      l10n.optionStoreControlCharactersNotAllowed,
    CommandOptionStoreFailure.fileChangedMeanwhile =>
      l10n.optionStoreFileChangedMeanwhile,
    CommandOptionStoreFailure.duplicateOptionValue =>
      l10n.optionStoreDuplicateOptionValue(detail),
    CommandOptionStoreFailure.newEntryNotValid =>
      l10n.optionStoreNewEntryNotValid,
    CommandOptionStoreFailure.optionValueNotFound =>
      l10n.optionStoreOptionValueNotFound(detail),
    CommandOptionStoreFailure.lastOptionCannotBeDeleted =>
      l10n.optionStoreLastOptionCannotBeDeleted,
    CommandOptionStoreFailure.unsupportedOptionListFormat =>
      l10n.optionStoreUnsupportedOptionListFormat,
    CommandOptionStoreFailure.entryNotFullyDeleted =>
      l10n.optionStoreEntryNotFullyDeleted,
    CommandOptionStoreFailure.invalidYamlRoot =>
      l10n.optionStoreInvalidYamlRoot,
    CommandOptionStoreFailure.missingParameterList =>
      l10n.optionStoreMissingParameterList,
    CommandOptionStoreFailure.optionsParameterNotFound =>
      l10n.optionStoreOptionsParameterNotFound(detail),
    CommandOptionStoreFailure.missingOptionList =>
      l10n.optionStoreMissingOptionList,
    CommandOptionStoreFailure.missingField => l10n.optionStoreMissingField(
      detail,
    ),
  };
}

String _batchStoreFailure(
  AppLocalizations l10n,
  BatchCommandStoreException error,
) {
  final detail = error.detail ?? '';
  return switch (error.failure) {
    BatchCommandStoreFailure.titleAndCommandRequired =>
      l10n.batchStoreTitleAndCommandRequired,
    BatchCommandStoreFailure.unsupportedCommandListFormat =>
      l10n.batchStoreUnsupportedCommandListFormat,
    BatchCommandStoreFailure.newCommandNotValid =>
      l10n.batchStoreNewCommandNotValid,
    BatchCommandStoreFailure.commandToDeleteNotFound =>
      l10n.batchStoreCommandToDeleteNotFound,
    BatchCommandStoreFailure.commandNotFullyDeleted =>
      l10n.batchStoreCommandNotFullyDeleted,
    BatchCommandStoreFailure.invalidYamlRoot => l10n.batchStoreInvalidYamlRoot,
    BatchCommandStoreFailure.missingCommandList =>
      l10n.batchStoreMissingCommandList,
    BatchCommandStoreFailure.fileChangedMeanwhile =>
      l10n.batchStoreFileChangedMeanwhile,
    BatchCommandStoreFailure.missingField => l10n.batchStoreMissingField(
      detail,
    ),
  };
}

String _tabFailure(AppLocalizations l10n, TerminalTabException error) {
  final detail = error.detail ?? '';
  return switch (error.failure) {
    TerminalTabFailure.unknownProfile => l10n.tabFailureUnknownProfile,
    TerminalTabFailure.savedTabsUnreadable =>
      l10n.tabFailureSavedTabsUnreadable(detail),
    TerminalTabFailure.sshTabsCannotBeSnapshotted =>
      l10n.tabFailureSshTabsCannotBeSnapshotted,
    TerminalTabFailure.nameMustNotBeEmpty => l10n.tabFailureNameMustNotBeEmpty,
    TerminalTabFailure.savedTabChangedMeanwhile =>
      l10n.tabFailureSavedTabChangedMeanwhile,
    TerminalTabFailure.invalidTabName => l10n.tabFailureInvalidTabName,
    TerminalTabFailure.integratedTerminalUnavailable =>
      l10n.tabFailureIntegratedTerminalUnavailable,
    TerminalTabFailure.shellProfileUnavailable =>
      l10n.tabFailureShellProfileUnavailable(detail),
  };
}

/// Renders a non-fatal import warning.
String localizeImportWarning(
  AppLocalizations l10n,
  SshBackupImportWarning warning,
) => switch (warning.kind) {
  SshBackupImportWarningKind.previousPasswordNotRemoved =>
    l10n.importWarningPreviousPasswordNotRemoved(warning.detail),
};

String _authFailure(AppLocalizations l10n, SshAuthenticationException error) {
  final profile = error.profileName ?? '';
  return switch (error.failure) {
    SshAuthenticationFailure.passphraseTooLong =>
      l10n.authFailurePassphraseTooLong,
    SshAuthenticationFailure.passphraseRequired =>
      l10n.authFailurePassphraseRequired,
    SshAuthenticationFailure.noPrivateKeyInFile =>
      l10n.authFailureNoPrivateKeyInFile,
    SshAuthenticationFailure.invalidKeyOrPassphrase =>
      l10n.authFailureInvalidKeyOrPassphrase,
    SshAuthenticationFailure.invalidOrUnsupportedKey =>
      l10n.authFailureInvalidOrUnsupportedKey,
    SshAuthenticationFailure.keyFileTooLarge => l10n.authFailureKeyFileTooLarge,
    SshAuthenticationFailure.keyFileUnreadable =>
      l10n.authFailureKeyFileUnreadable,
    SshAuthenticationFailure.keyFileNotUtf8 => l10n.authFailureKeyFileNotUtf8,
    SshAuthenticationFailure.noStoredPassword =>
      l10n.authFailureNoStoredPassword(profile),
    SshAuthenticationFailure.noPrivateKeyConfigured =>
      l10n.authFailureNoPrivateKeyConfigured(profile),
  };
}

String _backupFailure(AppLocalizations l10n, SshBackupException error) {
  final profile = error.profileName ?? '';
  final detail = error.detail ?? '';
  return switch (error.failure) {
    SshBackupFailure.invalidAuthenticationInBackup =>
      l10n.backupFailureInvalidAuthenticationInBackup,
    SshBackupFailure.invalidDataInBackup =>
      l10n.backupFailureInvalidDataInBackup,
    SshBackupFailure.selectAtLeastOneConnection =>
      l10n.backupFailureSelectAtLeastOneConnection,
    SshBackupFailure.tooManyConnectionsSelected =>
      l10n.backupFailureTooManyConnectionsSelected,
    SshBackupFailure.backupPasswordTooShort =>
      l10n.backupFailureBackupPasswordTooShort,
    SshBackupFailure.credentialsNotStored =>
      l10n.backupFailureCredentialsNotStored(profile),
    SshBackupFailure.fileTooLarge => l10n.backupFailureFileTooLarge,
    SshBackupFailure.backupPasswordMissing =>
      l10n.backupFailureBackupPasswordMissing,
    SshBackupFailure.invalidBackupParameters =>
      l10n.backupFailureInvalidBackupParameters,
    SshBackupFailure.invalidBackupCryptoData =>
      l10n.backupFailureInvalidBackupCryptoData,
    SshBackupFailure.invalidBackupContent =>
      l10n.backupFailureInvalidBackupContent,
    SshBackupFailure.invalidConnectionCount =>
      l10n.backupFailureInvalidConnectionCount,
    SshBackupFailure.invalidConnections => l10n.backupFailureInvalidConnections,
    SshBackupFailure.wrongPasswordOrTampered =>
      l10n.backupFailureWrongPasswordOrTampered,
    SshBackupFailure.connectionNotExportable =>
      l10n.backupFailureConnectionNotExportable,
    SshBackupFailure.unknownBackupFormat =>
      l10n.backupFailureUnknownBackupFormat,
    SshBackupFailure.profileReplacedTwice =>
      l10n.backupFailureProfileReplacedTwice(profile),
    SshBackupFailure.profileToReplaceNotFound =>
      l10n.backupFailureProfileToReplaceNotFound,
    SshBackupFailure.profilesChangedDuringImport =>
      l10n.backupFailureProfilesChangedDuringImport,
    // profileName carries the nested error for this one.
    SshBackupFailure.importFailedWithCleanup =>
      l10n.backupFailureImportFailedWithCleanup(profile, detail),
  };
}

String _persistedProblem(
  AppLocalizations l10n,
  PersistedDataException error,
) => switch (error.problem) {
  PersistedDataProblem.invalidSavedCommand => l10n.persistedInvalidSavedCommand,
  PersistedDataProblem.invalidSavedPane => l10n.persistedInvalidSavedPane,
  PersistedDataProblem.invalidSavedTab => l10n.persistedInvalidSavedTab,
  PersistedDataProblem.invalidPaneTopology => l10n.persistedInvalidPaneTopology,
  PersistedDataProblem.incompleteSplitPanes =>
    l10n.persistedIncompleteSplitPanes,
  PersistedDataProblem.invalidFocusedPane => l10n.persistedInvalidFocusedPane,
  PersistedDataProblem.invalidSshAuthentication =>
    l10n.persistedInvalidSshAuthentication,
  PersistedDataProblem.invalidSshProfile => l10n.persistedInvalidSshProfile,
  PersistedDataProblem.invalidSshHostKey => l10n.persistedInvalidSshHostKey,
  PersistedDataProblem.invalidSshProfileList =>
    l10n.persistedInvalidSshProfileList,
};

String _serviceFailure(AppLocalizations l10n, ServiceException error) =>
    switch (error.failure) {
      ServiceFailure.unsupportedLink => l10n.serviceUnsupportedLink(
        error.detail ?? '',
      ),
      ServiceFailure.linksNotOpenableOnPlatform =>
        l10n.serviceLinksNotOpenableOnPlatform,
      ServiceFailure.terminalDetectionUnsupported =>
        l10n.serviceTerminalDetectionUnsupported,
      ServiceFailure.sshProfileNotFound => l10n.serviceSshProfileNotFound,
    };

String _sessionFailure(AppLocalizations l10n, TerminalSessionException error) =>
    switch (error.failure) {
      TerminalSessionFailure.sessionNotRunning =>
        l10n.sessionFailureSessionNotRunning,
      TerminalSessionFailure.trackedCommandAlreadyRunning =>
        l10n.sessionFailureTrackedCommandAlreadyRunning,
      TerminalSessionFailure.nulNotAllowed => l10n.sessionFailureNulNotAllowed,
      TerminalSessionFailure.processCouldNotBeTerminated =>
        l10n.sessionFailureProcessCouldNotBeTerminated,
      TerminalSessionFailure.processDidNotExitInTime =>
        l10n.sessionFailureProcessDidNotExitInTime,
      TerminalSessionFailure.windowsHomePathNotAscii =>
        l10n.sessionFailureWindowsHomePathNotAscii,
      TerminalSessionFailure.shellExecutableEmpty =>
        l10n.sessionFailureShellExecutableEmpty,
      TerminalSessionFailure.windowsProfileNotAscii =>
        l10n.sessionFailureWindowsProfileNotAscii,
    };
