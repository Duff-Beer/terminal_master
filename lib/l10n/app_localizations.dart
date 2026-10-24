import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get commonDescription;

  /// No description provided for @buildFailurePipelineNeedsCommand.
  ///
  /// In en, this message translates to:
  /// **'Pipeline “{parameter}” needs a command.'**
  String buildFailurePipelineNeedsCommand(String parameter);

  /// No description provided for @buildFailureCommandIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The command to run is empty.'**
  String get buildFailureCommandIsEmpty;

  /// No description provided for @buildFailureInvalidButtonAction.
  ///
  /// In en, this message translates to:
  /// **'Invalid button action.'**
  String get buildFailureInvalidButtonAction;

  /// No description provided for @buildFailureRequiredParameterMissing.
  ///
  /// In en, this message translates to:
  /// **'Required parameter “{parameter}” is missing.'**
  String buildFailureRequiredParameterMissing(String parameter);

  /// No description provided for @buildFailureParameterRequiresOther.
  ///
  /// In en, this message translates to:
  /// **'Parameter “{parameter}” requires “{other}”.'**
  String buildFailureParameterRequiresOther(String parameter, String other);

  /// No description provided for @buildFailureParameterConflictsWithOther.
  ///
  /// In en, this message translates to:
  /// **'Parameter “{parameter}” cannot be used together with “{other}”.'**
  String buildFailureParameterConflictsWithOther(
    String parameter,
    String other,
  );

  /// No description provided for @buildFailureParameterMustDifferFromOther.
  ///
  /// In en, this message translates to:
  /// **'Parameter “{parameter}” must differ from “{other}”.'**
  String buildFailureParameterMustDifferFromOther(
    String parameter,
    String other,
  );

  /// No description provided for @buildFailureInvalidOptionValue.
  ///
  /// In en, this message translates to:
  /// **'Parameter “{parameter}” contains an invalid option value.'**
  String buildFailureInvalidOptionValue(String parameter);

  /// No description provided for @buildFailureDdInputEqualsOutput.
  ///
  /// In en, this message translates to:
  /// **'The input and output of dd must differ.'**
  String get buildFailureDdInputEqualsOutput;

  /// No description provided for @buildFailureMultipleValuesNotAttachable.
  ///
  /// In en, this message translates to:
  /// **'Parameter “{parameter}” cannot attach multiple values directly to one flag.'**
  String buildFailureMultipleValuesNotAttachable(String parameter);

  /// No description provided for @buildFailureInvalidConfigurationValue.
  ///
  /// In en, this message translates to:
  /// **'Invalid configuration value: {detail}'**
  String buildFailureInvalidConfigurationValue(String detail);

  /// No description provided for @buildFailureParameterMustBeList.
  ///
  /// In en, this message translates to:
  /// **'Parameter “{parameter}” must contain a list.'**
  String buildFailureParameterMustBeList(String parameter);

  /// No description provided for @buildFailureControlCharactersNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Command arguments must not contain control characters.'**
  String get buildFailureControlCharactersNotAllowed;

  /// No description provided for @buildFailureUnsafeWindowsCharacter.
  ///
  /// In en, this message translates to:
  /// **'The Windows shell cannot safely handle this character in input values.'**
  String get buildFailureUnsafeWindowsCharacter;

  /// No description provided for @optionStoreValueAndDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Value and description must not be empty.'**
  String get optionStoreValueAndDescriptionRequired;

  /// No description provided for @optionStoreControlCharactersNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Value and description must not contain control characters.'**
  String get optionStoreControlCharactersNotAllowed;

  /// No description provided for @optionStoreFileChangedMeanwhile.
  ///
  /// In en, this message translates to:
  /// **'The YAML file changed in the meantime. Open it again.'**
  String get optionStoreFileChangedMeanwhile;

  /// No description provided for @optionStoreDuplicateOptionValue.
  ///
  /// In en, this message translates to:
  /// **'The option value “{value}” already exists.'**
  String optionStoreDuplicateOptionValue(String value);

  /// No description provided for @optionStoreNewEntryNotValid.
  ///
  /// In en, this message translates to:
  /// **'The new entry could not be validated.'**
  String get optionStoreNewEntryNotValid;

  /// No description provided for @optionStoreOptionValueNotFound.
  ///
  /// In en, this message translates to:
  /// **'The option value “{value}” was not found.'**
  String optionStoreOptionValueNotFound(String value);

  /// No description provided for @optionStoreLastOptionCannotBeDeleted.
  ///
  /// In en, this message translates to:
  /// **'The last option value cannot be deleted.'**
  String get optionStoreLastOptionCannotBeDeleted;

  /// No description provided for @optionStoreUnsupportedOptionListFormat.
  ///
  /// In en, this message translates to:
  /// **'The option list uses an unsupported YAML format.'**
  String get optionStoreUnsupportedOptionListFormat;

  /// No description provided for @optionStoreEntryNotFullyDeleted.
  ///
  /// In en, this message translates to:
  /// **'The entry could not be deleted completely.'**
  String get optionStoreEntryNotFullyDeleted;

  /// No description provided for @optionStoreInvalidYamlRoot.
  ///
  /// In en, this message translates to:
  /// **'The YAML root is invalid.'**
  String get optionStoreInvalidYamlRoot;

  /// No description provided for @optionStoreMissingParameterList.
  ///
  /// In en, this message translates to:
  /// **'The parameter list is missing.'**
  String get optionStoreMissingParameterList;

  /// No description provided for @optionStoreOptionsParameterNotFound.
  ///
  /// In en, this message translates to:
  /// **'The options parameter “{name}” was not found.'**
  String optionStoreOptionsParameterNotFound(String name);

  /// No description provided for @optionStoreMissingOptionList.
  ///
  /// In en, this message translates to:
  /// **'The option list is missing.'**
  String get optionStoreMissingOptionList;

  /// No description provided for @optionStoreMissingField.
  ///
  /// In en, this message translates to:
  /// **'The field “{field}” is missing.'**
  String optionStoreMissingField(String field);

  /// No description provided for @batchStoreTitleAndCommandRequired.
  ///
  /// In en, this message translates to:
  /// **'Title and command must not be empty.'**
  String get batchStoreTitleAndCommandRequired;

  /// No description provided for @batchStoreUnsupportedCommandListFormat.
  ///
  /// In en, this message translates to:
  /// **'The command list uses an unsupported YAML format.'**
  String get batchStoreUnsupportedCommandListFormat;

  /// No description provided for @batchStoreNewCommandNotValid.
  ///
  /// In en, this message translates to:
  /// **'The new command could not be validated.'**
  String get batchStoreNewCommandNotValid;

  /// No description provided for @batchStoreCommandToDeleteNotFound.
  ///
  /// In en, this message translates to:
  /// **'The command to delete was not found.'**
  String get batchStoreCommandToDeleteNotFound;

  /// No description provided for @batchStoreCommandNotFullyDeleted.
  ///
  /// In en, this message translates to:
  /// **'The command could not be deleted completely.'**
  String get batchStoreCommandNotFullyDeleted;

  /// No description provided for @batchStoreInvalidYamlRoot.
  ///
  /// In en, this message translates to:
  /// **'The YAML root is invalid.'**
  String get batchStoreInvalidYamlRoot;

  /// No description provided for @batchStoreMissingCommandList.
  ///
  /// In en, this message translates to:
  /// **'The command list is missing.'**
  String get batchStoreMissingCommandList;

  /// No description provided for @batchStoreFileChangedMeanwhile.
  ///
  /// In en, this message translates to:
  /// **'The YAML file changed in the meantime. Open it again.'**
  String get batchStoreFileChangedMeanwhile;

  /// No description provided for @batchStoreMissingField.
  ///
  /// In en, this message translates to:
  /// **'The field “{field}” is missing.'**
  String batchStoreMissingField(String field);

  /// No description provided for @tabFailureUnknownProfile.
  ///
  /// In en, this message translates to:
  /// **'Unknown profile.'**
  String get tabFailureUnknownProfile;

  /// No description provided for @tabFailureSavedTabsUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Saved tabs could not be loaded: {detail}'**
  String tabFailureSavedTabsUnreadable(String detail);

  /// No description provided for @tabFailureSshTabsCannotBeSnapshotted.
  ///
  /// In en, this message translates to:
  /// **'For security reasons, SSH terminal tabs cannot be stored as a terminal snapshot.'**
  String get tabFailureSshTabsCannotBeSnapshotted;

  /// No description provided for @tabFailureNameMustNotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'The name must not be empty.'**
  String get tabFailureNameMustNotBeEmpty;

  /// No description provided for @tabFailureSavedTabChangedMeanwhile.
  ///
  /// In en, this message translates to:
  /// **'This saved tab changed in the meantime. Open the current version again.'**
  String get tabFailureSavedTabChangedMeanwhile;

  /// No description provided for @tabFailureInvalidTabName.
  ///
  /// In en, this message translates to:
  /// **'Invalid terminal tab name.'**
  String get tabFailureInvalidTabName;

  /// No description provided for @tabFailureIntegratedTerminalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The built-in terminal is not available.'**
  String get tabFailureIntegratedTerminalUnavailable;

  /// No description provided for @tabFailureShellProfileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The shell profile “{profile}” is not available.'**
  String tabFailureShellProfileUnavailable(String profile);

  /// No description provided for @authFailurePassphraseTooLong.
  ///
  /// In en, this message translates to:
  /// **'The key passphrase is too long.'**
  String get authFailurePassphraseTooLong;

  /// No description provided for @authFailurePassphraseRequired.
  ///
  /// In en, this message translates to:
  /// **'The private SSH key needs a passphrase.'**
  String get authFailurePassphraseRequired;

  /// No description provided for @authFailureNoPrivateKeyInFile.
  ///
  /// In en, this message translates to:
  /// **'The file does not contain a private SSH key.'**
  String get authFailureNoPrivateKeyInFile;

  /// No description provided for @authFailureInvalidKeyOrPassphrase.
  ///
  /// In en, this message translates to:
  /// **'The private SSH key or its passphrase is invalid or unsupported.'**
  String get authFailureInvalidKeyOrPassphrase;

  /// No description provided for @authFailureInvalidOrUnsupportedKey.
  ///
  /// In en, this message translates to:
  /// **'The private SSH key is invalid or unsupported.'**
  String get authFailureInvalidOrUnsupportedKey;

  /// No description provided for @authFailureKeyFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The private key file is too large.'**
  String get authFailureKeyFileTooLarge;

  /// No description provided for @authFailureKeyFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The private key file could not be read.'**
  String get authFailureKeyFileUnreadable;

  /// No description provided for @authFailureKeyFileNotUtf8.
  ///
  /// In en, this message translates to:
  /// **'The private key file is not a valid UTF-8 text file.'**
  String get authFailureKeyFileNotUtf8;

  /// No description provided for @authFailureNoStoredPassword.
  ///
  /// In en, this message translates to:
  /// **'No password is stored in the keychain for “{profile}”.'**
  String authFailureNoStoredPassword(String profile);

  /// No description provided for @authFailureNoPrivateKeyConfigured.
  ///
  /// In en, this message translates to:
  /// **'No private key file is configured for “{profile}”.'**
  String authFailureNoPrivateKeyConfigured(String profile);

  /// No description provided for @backupFailureInvalidAuthenticationInBackup.
  ///
  /// In en, this message translates to:
  /// **'The SSH backup contains an invalid authentication type.'**
  String get backupFailureInvalidAuthenticationInBackup;

  /// No description provided for @backupFailureInvalidDataInBackup.
  ///
  /// In en, this message translates to:
  /// **'The SSH backup contains invalid data.'**
  String get backupFailureInvalidDataInBackup;

  /// No description provided for @backupFailureSelectAtLeastOneConnection.
  ///
  /// In en, this message translates to:
  /// **'Select at least one SSH connection.'**
  String get backupFailureSelectAtLeastOneConnection;

  /// No description provided for @backupFailureTooManyConnectionsSelected.
  ///
  /// In en, this message translates to:
  /// **'Too many SSH connections selected.'**
  String get backupFailureTooManyConnectionsSelected;

  /// No description provided for @backupFailureBackupPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'The backup password must be at least 12 characters long.'**
  String get backupFailureBackupPasswordTooShort;

  /// No description provided for @backupFailureCredentialsNotStored.
  ///
  /// In en, this message translates to:
  /// **'The credentials required for “{profile}” are not stored.'**
  String backupFailureCredentialsNotStored(String profile);

  /// No description provided for @backupFailureFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The backup file is too large.'**
  String get backupFailureFileTooLarge;

  /// No description provided for @backupFailureBackupPasswordMissing.
  ///
  /// In en, this message translates to:
  /// **'The backup password is missing.'**
  String get backupFailureBackupPasswordMissing;

  /// No description provided for @backupFailureInvalidBackupParameters.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup parameters.'**
  String get backupFailureInvalidBackupParameters;

  /// No description provided for @backupFailureInvalidBackupCryptoData.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup cryptographic data.'**
  String get backupFailureInvalidBackupCryptoData;

  /// No description provided for @backupFailureInvalidBackupContent.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup content.'**
  String get backupFailureInvalidBackupContent;

  /// No description provided for @backupFailureInvalidConnectionCount.
  ///
  /// In en, this message translates to:
  /// **'The backup contains an invalid number of connections.'**
  String get backupFailureInvalidConnectionCount;

  /// No description provided for @backupFailureInvalidConnections.
  ///
  /// In en, this message translates to:
  /// **'The backup contains invalid connections.'**
  String get backupFailureInvalidConnections;

  /// No description provided for @backupFailureWrongPasswordOrTampered.
  ///
  /// In en, this message translates to:
  /// **'The backup password is wrong or the file was modified.'**
  String get backupFailureWrongPasswordOrTampered;

  /// No description provided for @backupFailureConnectionNotExportable.
  ///
  /// In en, this message translates to:
  /// **'An SSH connection contains data that cannot be exported.'**
  String get backupFailureConnectionNotExportable;

  /// No description provided for @backupFailureUnknownBackupFormat.
  ///
  /// In en, this message translates to:
  /// **'Unknown SSH backup format.'**
  String get backupFailureUnknownBackupFormat;

  /// No description provided for @backupFailureProfileReplacedTwice.
  ///
  /// In en, this message translates to:
  /// **'The profile “{profile}” cannot be replaced more than once.'**
  String backupFailureProfileReplacedTwice(String profile);

  /// No description provided for @backupFailureProfileToReplaceNotFound.
  ///
  /// In en, this message translates to:
  /// **'An SSH profile to be replaced was not found.'**
  String get backupFailureProfileToReplaceNotFound;

  /// No description provided for @backupFailureProfilesChangedDuringImport.
  ///
  /// In en, this message translates to:
  /// **'The SSH profiles changed during the import. Start the import again.'**
  String get backupFailureProfilesChangedDuringImport;

  /// No description provided for @backupFailureImportFailedWithCleanup.
  ///
  /// In en, this message translates to:
  /// **'{error}\nTemporary keychain entries could not be removed either: {detail}'**
  String backupFailureImportFailedWithCleanup(String error, String detail);

  /// No description provided for @importWarningPreviousPasswordNotRemoved.
  ///
  /// In en, this message translates to:
  /// **'A previous password could not be removed: {detail}'**
  String importWarningPreviousPasswordNotRemoved(String detail);

  /// No description provided for @persistedInvalidSavedCommand.
  ///
  /// In en, this message translates to:
  /// **'Invalid saved command.'**
  String get persistedInvalidSavedCommand;

  /// No description provided for @persistedInvalidSavedPane.
  ///
  /// In en, this message translates to:
  /// **'Invalid saved terminal pane.'**
  String get persistedInvalidSavedPane;

  /// No description provided for @persistedInvalidSavedTab.
  ///
  /// In en, this message translates to:
  /// **'Invalid saved terminal tab.'**
  String get persistedInvalidSavedTab;

  /// No description provided for @persistedInvalidPaneTopology.
  ///
  /// In en, this message translates to:
  /// **'Invalid pane topology.'**
  String get persistedInvalidPaneTopology;

  /// No description provided for @persistedInvalidSshAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Invalid SSH authentication.'**
  String get persistedInvalidSshAuthentication;

  /// No description provided for @persistedInvalidSshProfile.
  ///
  /// In en, this message translates to:
  /// **'Invalid SSH connection profile.'**
  String get persistedInvalidSshProfile;

  /// No description provided for @persistedInvalidSshHostKey.
  ///
  /// In en, this message translates to:
  /// **'Invalid SSH host key.'**
  String get persistedInvalidSshHostKey;

  /// No description provided for @persistedInvalidSshProfileList.
  ///
  /// In en, this message translates to:
  /// **'Invalid SSH profile list.'**
  String get persistedInvalidSshProfileList;

  /// No description provided for @serviceUnsupportedLink.
  ///
  /// In en, this message translates to:
  /// **'Unsupported link: {uri}'**
  String serviceUnsupportedLink(String uri);

  /// No description provided for @serviceLinksNotOpenableOnPlatform.
  ///
  /// In en, this message translates to:
  /// **'Links are not opened on this platform.'**
  String get serviceLinksNotOpenableOnPlatform;

  /// No description provided for @serviceTerminalDetectionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Terminal detection is not supported on this platform.'**
  String get serviceTerminalDetectionUnsupported;

  /// No description provided for @serviceSshProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'The SSH connection profile was not found.'**
  String get serviceSshProfileNotFound;

  /// No description provided for @sessionFailureSessionNotRunning.
  ///
  /// In en, this message translates to:
  /// **'The terminal session is not running.'**
  String get sessionFailureSessionNotRunning;

  /// No description provided for @sessionFailureTrackedCommandAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'A tracked command is already running in this terminal.'**
  String get sessionFailureTrackedCommandAlreadyRunning;

  /// No description provided for @sessionFailureNulNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'NUL is not allowed.'**
  String get sessionFailureNulNotAllowed;

  /// No description provided for @sessionFailureProcessCouldNotBeTerminated.
  ///
  /// In en, this message translates to:
  /// **'The terminal process could not be terminated.'**
  String get sessionFailureProcessCouldNotBeTerminated;

  /// No description provided for @sessionFailureProcessDidNotExitInTime.
  ///
  /// In en, this message translates to:
  /// **'The terminal process did not exit within the time limit.'**
  String get sessionFailureProcessDidNotExitInTime;

  /// No description provided for @sessionFailureWindowsHomePathNotAscii.
  ///
  /// In en, this message translates to:
  /// **'flutter_pty does not currently support Windows user paths containing non-ASCII characters. Use the external terminal for now.'**
  String get sessionFailureWindowsHomePathNotAscii;

  /// No description provided for @sessionFailureShellExecutableEmpty.
  ///
  /// In en, this message translates to:
  /// **'The shell program must not be empty.'**
  String get sessionFailureShellExecutableEmpty;

  /// No description provided for @sessionFailureWindowsProfileNotAscii.
  ///
  /// In en, this message translates to:
  /// **'flutter_pty currently supports only ASCII characters in built-in shell profiles on Windows. Use the external terminal for now.'**
  String get sessionFailureWindowsProfileNotAscii;

  /// No description provided for @configErrorAt.
  ///
  /// In en, this message translates to:
  /// **'{file}: {field}: {reason}'**
  String configErrorAt(String file, String field, String reason);

  /// No description provided for @configReasonMustBeList.
  ///
  /// In en, this message translates to:
  /// **'must be a list'**
  String get configReasonMustBeList;

  /// No description provided for @configReasonMustBeNonEmptyList.
  ///
  /// In en, this message translates to:
  /// **'must be a non-empty list'**
  String get configReasonMustBeNonEmptyList;

  /// No description provided for @configReasonMustBeObject.
  ///
  /// In en, this message translates to:
  /// **'must be an object'**
  String get configReasonMustBeObject;

  /// No description provided for @configReasonMustBeText.
  ///
  /// In en, this message translates to:
  /// **'must contain text'**
  String get configReasonMustBeText;

  /// No description provided for @configReasonMustBeBoolean.
  ///
  /// In en, this message translates to:
  /// **'must be true or false'**
  String get configReasonMustBeBoolean;

  /// No description provided for @configReasonMustBeInteger.
  ///
  /// In en, this message translates to:
  /// **'must be a whole number'**
  String get configReasonMustBeInteger;

  /// No description provided for @configReasonMustBeTextList.
  ///
  /// In en, this message translates to:
  /// **'must be a list of text'**
  String get configReasonMustBeTextList;

  /// No description provided for @configReasonMustBeTextOrBoolean.
  ///
  /// In en, this message translates to:
  /// **'must be text, true or false'**
  String get configReasonMustBeTextOrBoolean;

  /// No description provided for @configReasonMustBeFilePickerMode.
  ///
  /// In en, this message translates to:
  /// **'must be file, directory or any'**
  String get configReasonMustBeFilePickerMode;

  /// No description provided for @configReasonMustBeExecutionMode.
  ///
  /// In en, this message translates to:
  /// **'must be automatic, before_command, argument or pipeline'**
  String get configReasonMustBeExecutionMode;

  /// No description provided for @configReasonMustBeAttachmentMode.
  ///
  /// In en, this message translates to:
  /// **'must be automatic, separated or attached'**
  String get configReasonMustBeAttachmentMode;

  /// No description provided for @configReasonOptionsParameterNeedsEntry.
  ///
  /// In en, this message translates to:
  /// **'an options parameter needs at least one entry'**
  String get configReasonOptionsParameterNeedsEntry;

  /// No description provided for @configReasonButtonNeedsExecutable.
  ///
  /// In en, this message translates to:
  /// **'a button needs an executable program'**
  String get configReasonButtonNeedsExecutable;

  /// No description provided for @configReasonTypeMismatch.
  ///
  /// In en, this message translates to:
  /// **'does not have the data type matching the parameter type'**
  String get configReasonTypeMismatch;

  /// No description provided for @configReasonNotInOptions.
  ///
  /// In en, this message translates to:
  /// **'is not contained in options'**
  String get configReasonNotInOptions;

  /// No description provided for @configReasonDuplicateParameterName.
  ///
  /// In en, this message translates to:
  /// **'parameter name “{name}” appears more than once'**
  String configReasonDuplicateParameterName(String name);

  /// No description provided for @configReasonDuplicateOptionValue.
  ///
  /// In en, this message translates to:
  /// **'option value “{value}” appears more than once'**
  String configReasonDuplicateOptionValue(String value);

  /// No description provided for @configReasonUnknownParameterType.
  ///
  /// In en, this message translates to:
  /// **'unknown parameter type “{type}”'**
  String configReasonUnknownParameterType(String type);

  /// No description provided for @configReasonUnknownParameterReference.
  ///
  /// In en, this message translates to:
  /// **'refers to unknown parameter “{name}”'**
  String configReasonUnknownParameterReference(String name);

  /// No description provided for @configReasonUnknownFields.
  ///
  /// In en, this message translates to:
  /// **'contains unknown fields: {fields}'**
  String configReasonUnknownFields(String fields);

  /// No description provided for @configReasonUnknownGroupFields.
  ///
  /// In en, this message translates to:
  /// **'contains unknown group fields: {fields}'**
  String configReasonUnknownGroupFields(String fields);

  /// No description provided for @configReasonConditionSelfReference.
  ///
  /// In en, this message translates to:
  /// **'a condition must not refer to its own parameter'**
  String get configReasonConditionSelfReference;

  /// No description provided for @configReasonConditionValueTypeMismatch.
  ///
  /// In en, this message translates to:
  /// **'condition value does not match the type of “{name}”'**
  String configReasonConditionValueTypeMismatch(String name);

  /// No description provided for @configReasonConditionValueNotAnOption.
  ///
  /// In en, this message translates to:
  /// **'condition value is not an option of “{name}”'**
  String configReasonConditionValueNotAnOption(String name);

  /// No description provided for @configReasonBothAllAndAny.
  ///
  /// In en, this message translates to:
  /// **'must not contain all and any at the same time'**
  String get configReasonBothAllAndAny;

  /// No description provided for @configReasonNeedsAtLeastOneCondition.
  ///
  /// In en, this message translates to:
  /// **'must contain at least one condition'**
  String get configReasonNeedsAtLeastOneCondition;

  /// No description provided for @configReasonOnlyEqualsInOrActive.
  ///
  /// In en, this message translates to:
  /// **'may only use equals, in or active'**
  String get configReasonOnlyEqualsInOrActive;

  /// No description provided for @configReasonUnsupportedSchemaVersion.
  ///
  /// In en, this message translates to:
  /// **'only version {version} is supported'**
  String configReasonUnsupportedSchemaVersion(String version);

  /// No description provided for @configReasonFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'file was not found'**
  String get configReasonFileNotFound;

  /// No description provided for @configReasonFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'file could not be read: {detail}'**
  String configReasonFileUnreadable(String detail);

  /// No description provided for @configReasonInvalidYaml.
  ///
  /// In en, this message translates to:
  /// **'invalid YAML: {detail}'**
  String configReasonInvalidYaml(String detail);

  /// No description provided for @configItemBatchCommands.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 command in this file} other{{count} commands in this file}}'**
  String configItemBatchCommands(int count);

  /// No description provided for @configItemNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get configItemNoDescription;

  /// No description provided for @configItemLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error: {file}'**
  String configItemLoadError(String file);

  /// No description provided for @configErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration error'**
  String get configErrorTitle;

  /// No description provided for @outputTitle.
  ///
  /// In en, this message translates to:
  /// **'Command Output'**
  String get outputTitle;

  /// No description provided for @generatorAddOptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add entry to {parameter}'**
  String generatorAddOptionTitle(String parameter);

  /// No description provided for @generatorFieldValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get generatorFieldValue;

  /// No description provided for @generatorOptionSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the entry: {error}'**
  String generatorOptionSaveFailed(String error);

  /// No description provided for @generatorOptionDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the entry: {error}'**
  String generatorOptionDeleteFailed(String error);

  /// No description provided for @generatorBuildFailed.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String generatorBuildFailed(String error);

  /// No description provided for @generatorExecuteFailed.
  ///
  /// In en, this message translates to:
  /// **'Execution failed: {error}'**
  String generatorExecuteFailed(String error);

  /// No description provided for @generatorActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String generatorActionFailed(String error);

  /// No description provided for @generatorCommandCopied.
  ///
  /// In en, this message translates to:
  /// **'Command copied to clipboard:\n{command}'**
  String generatorCommandCopied(String command);

  /// No description provided for @generatorBuildCommand.
  ///
  /// In en, this message translates to:
  /// **'Build command'**
  String get generatorBuildCommand;

  /// No description provided for @generatorPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get generatorPreparing;

  /// No description provided for @generatorInsertIntoTerminal.
  ///
  /// In en, this message translates to:
  /// **'Insert into terminal'**
  String get generatorInsertIntoTerminal;

  /// No description provided for @generatorRunCommand.
  ///
  /// In en, this message translates to:
  /// **'Run command'**
  String get generatorRunCommand;

  /// No description provided for @generatorIntegratedTerminal.
  ///
  /// In en, this message translates to:
  /// **'Built-in terminal'**
  String get generatorIntegratedTerminal;

  /// No description provided for @generatorIntegratedTerminalOn.
  ///
  /// In en, this message translates to:
  /// **'Run the command inside Terminal Master'**
  String get generatorIntegratedTerminalOn;

  /// No description provided for @generatorIntegratedTerminalOff.
  ///
  /// In en, this message translates to:
  /// **'Use the configured external terminal app'**
  String get generatorIntegratedTerminalOff;

  /// No description provided for @generatorNewExternalTerminal.
  ///
  /// In en, this message translates to:
  /// **'New external terminal'**
  String get generatorNewExternalTerminal;

  /// No description provided for @pickDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select folder'**
  String get pickDirectory;

  /// No description provided for @pickFileOrDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select file or folder'**
  String get pickFileOrDirectory;

  /// No description provided for @pickFile.
  ///
  /// In en, this message translates to:
  /// **'Select file'**
  String get pickFile;

  /// No description provided for @listRemoveEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove entry'**
  String get listRemoveEntry;

  /// No description provided for @listAddEntry.
  ///
  /// In en, this message translates to:
  /// **'Add another entry'**
  String get listAddEntry;

  /// No description provided for @riskReasonRmDeletesPermanently.
  ///
  /// In en, this message translates to:
  /// **'rm can permanently delete files and directories.'**
  String get riskReasonRmDeletesPermanently;

  /// No description provided for @riskReasonDdOverwrites.
  ///
  /// In en, this message translates to:
  /// **'dd can overwrite files, drives and partitions.'**
  String get riskReasonDdOverwrites;

  /// No description provided for @riskReasonForceOptionSkipsPrompts.
  ///
  /// In en, this message translates to:
  /// **'The force option skips the normal safety prompts.'**
  String get riskReasonForceOptionSkipsPrompts;

  /// No description provided for @riskReasonElevatedPrivileges.
  ///
  /// In en, this message translates to:
  /// **'The command runs with elevated privileges.'**
  String get riskReasonElevatedPrivileges;

  /// No description provided for @riskReasonBatchMayDeleteOrOverwrite.
  ///
  /// In en, this message translates to:
  /// **'At least one batch command can delete or overwrite data.'**
  String get riskReasonBatchMayDeleteOrOverwrite;

  /// No description provided for @riskReasonBatchUsesForce.
  ///
  /// In en, this message translates to:
  /// **'At least one batch command uses a force option.'**
  String get riskReasonBatchUsesForce;

  /// No description provided for @riskReasonBatchUsesElevatedPrivileges.
  ///
  /// In en, this message translates to:
  /// **'At least one batch command uses elevated privileges.'**
  String get riskReasonBatchUsesElevatedPrivileges;

  /// No description provided for @confirmTitleStandard.
  ///
  /// In en, this message translates to:
  /// **'Review command'**
  String get confirmTitleStandard;

  /// No description provided for @confirmTitleElevated.
  ///
  /// In en, this message translates to:
  /// **'Confirm elevated privileges'**
  String get confirmTitleElevated;

  /// No description provided for @confirmTitleDestructive.
  ///
  /// In en, this message translates to:
  /// **'Confirm destructive command'**
  String get confirmTitleDestructive;

  /// No description provided for @confirmRawConfigWarning.
  ///
  /// In en, this message translates to:
  /// **'These commands come straight from a YAML file. Only run them if you trust the file and its contents.'**
  String get confirmRawConfigWarning;

  /// No description provided for @confirmCommandsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Command to run} other{Commands to run}}'**
  String confirmCommandsLabel(int count);

  /// No description provided for @confirmAcknowledgement.
  ///
  /// In en, this message translates to:
  /// **'I have reviewed the command and understand the risk.'**
  String get confirmAcknowledgement;

  /// No description provided for @confirmRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get confirmRun;

  /// No description provided for @optionsPleaseSelect.
  ///
  /// In en, this message translates to:
  /// **'Please select'**
  String get optionsPleaseSelect;

  /// No description provided for @optionsNotUsed.
  ///
  /// In en, this message translates to:
  /// **'Do not use'**
  String get optionsNotUsed;

  /// No description provided for @optionsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search value or description'**
  String get optionsSearchHint;

  /// No description provided for @optionsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get optionsNoMatches;

  /// No description provided for @optionsAddEntry.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get optionsAddEntry;

  /// No description provided for @optionsDeleteEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get optionsDeleteEntry;

  /// No description provided for @optionsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete entry?'**
  String get optionsDeleteTitle;

  /// No description provided for @optionsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete “{value}” from the YAML file?'**
  String optionsDeleteMessage(String value);

  /// No description provided for @mainTitle.
  ///
  /// In en, this message translates to:
  /// **'Command Builder'**
  String get mainTitle;

  /// No description provided for @mainSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search templates'**
  String get mainSearchHint;

  /// No description provided for @mainDirectoryNotFound.
  ///
  /// In en, this message translates to:
  /// **'Folder not found.'**
  String get mainDirectoryNotFound;

  /// No description provided for @mainPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied to clipboard'**
  String get mainPathCopied;

  /// No description provided for @mainRevealInFileManager.
  ///
  /// In en, this message translates to:
  /// **'Show in file manager'**
  String get mainRevealInFileManager;

  /// No description provided for @mainRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get mainRefresh;

  /// No description provided for @mainNoConfigFiles.
  ///
  /// In en, this message translates to:
  /// **'No config files found'**
  String get mainNoConfigFiles;

  /// No description provided for @batchTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch Commands'**
  String get batchTitle;

  /// No description provided for @batchAddCommand.
  ///
  /// In en, this message translates to:
  /// **'Add batch command'**
  String get batchAddCommand;

  /// No description provided for @batchFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get batchFieldTitle;

  /// No description provided for @batchFieldCommand.
  ///
  /// In en, this message translates to:
  /// **'Command *'**
  String get batchFieldCommand;

  /// No description provided for @batchUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get batchUntitled;

  /// No description provided for @batchNoCommands.
  ///
  /// In en, this message translates to:
  /// **'No commands found.'**
  String get batchNoCommands;

  /// No description provided for @batchDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete batch command?'**
  String get batchDeleteTitle;

  /// No description provided for @batchDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete “{title}”?'**
  String batchDeleteMessage(String title);

  /// No description provided for @batchSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the command: {error}'**
  String batchSaveFailed(String error);

  /// No description provided for @batchDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the command: {error}'**
  String batchDeleteFailed(String error);

  /// No description provided for @batchInsertFailed.
  ///
  /// In en, this message translates to:
  /// **'Insert failed: {error}'**
  String batchInsertFailed(String error);

  /// No description provided for @batchInsertIntoTerminal.
  ///
  /// In en, this message translates to:
  /// **'Insert into the built-in terminal'**
  String get batchInsertIntoTerminal;

  /// No description provided for @batchCopyCommand.
  ///
  /// In en, this message translates to:
  /// **'Copy command'**
  String get batchCopyCommand;

  /// No description provided for @batchCommandCopied.
  ///
  /// In en, this message translates to:
  /// **'Command copied to clipboard'**
  String get batchCommandCopied;

  /// No description provided for @batchDeleteCommand.
  ///
  /// In en, this message translates to:
  /// **'Delete batch command'**
  String get batchDeleteCommand;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get commonPaste;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @railClose.
  ///
  /// In en, this message translates to:
  /// **'Close {tool}'**
  String railClose(String tool);

  /// No description provided for @terminalCommandHint.
  ///
  /// In en, this message translates to:
  /// **'Commands for {profile} …'**
  String terminalCommandHint(String profile);

  /// No description provided for @terminalSendToTerminal.
  ///
  /// In en, this message translates to:
  /// **'Send to terminal'**
  String get terminalSendToTerminal;

  /// No description provided for @terminalSearch.
  ///
  /// In en, this message translates to:
  /// **'Search terminal'**
  String get terminalSearch;

  /// No description provided for @terminalCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get terminalCloseSearch;

  /// No description provided for @terminalMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More terminal actions'**
  String get terminalMoreActions;

  /// No description provided for @terminalRestartSession.
  ///
  /// In en, this message translates to:
  /// **'Restart session'**
  String get terminalRestartSession;

  /// No description provided for @terminalCloseTabHint.
  ///
  /// In en, this message translates to:
  /// **'Close tab · right-click for tab actions'**
  String get terminalCloseTabHint;

  /// No description provided for @terminalNewTab.
  ///
  /// In en, this message translates to:
  /// **'New terminal tab'**
  String get terminalNewTab;

  /// No description provided for @terminalOpenSavedTab.
  ///
  /// In en, this message translates to:
  /// **'Open saved terminal tab'**
  String get terminalOpenSavedTab;

  /// No description provided for @terminalNoSavedTabs.
  ///
  /// In en, this message translates to:
  /// **'No saved tabs'**
  String get terminalNoSavedTabs;

  /// No description provided for @terminalSaveTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Save terminal tab'**
  String get terminalSaveTabTitle;

  /// No description provided for @terminalUpdateSavedTab.
  ///
  /// In en, this message translates to:
  /// **'Update saved tab'**
  String get terminalUpdateSavedTab;

  /// No description provided for @terminalSaveTabNote.
  ///
  /// In en, this message translates to:
  /// **'Up to 20 command block commands are stored per pane. Commands may contain sensitive values; terminal output is not stored.'**
  String get terminalSaveTabNote;

  /// No description provided for @terminalTabSaved.
  ///
  /// In en, this message translates to:
  /// **'Terminal tab “{name}” was saved.'**
  String terminalTabSaved(String name);

  /// No description provided for @terminalSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Saving failed: {error}'**
  String terminalSaveFailed(String error);

  /// No description provided for @terminalOpenSnapshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Open “{name}”'**
  String terminalOpenSnapshotTitle(String name);

  /// No description provided for @terminalSnapshotSummary.
  ///
  /// In en, this message translates to:
  /// **'{panes} terminal panes · {commands} saved commands'**
  String terminalSnapshotSummary(int panes, int commands);

  /// No description provided for @terminalPinCommandBar.
  ///
  /// In en, this message translates to:
  /// **'Keep command bar visible'**
  String get terminalPinCommandBar;

  /// No description provided for @terminalUseAutomaticCommandBar.
  ///
  /// In en, this message translates to:
  /// **'Automatically show/hide command bar'**
  String get terminalUseAutomaticCommandBar;

  /// No description provided for @terminalDeleteSavedTab.
  ///
  /// In en, this message translates to:
  /// **'Delete saved state'**
  String get terminalDeleteSavedTab;

  /// No description provided for @terminalDeleteSavedTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete saved state?'**
  String get terminalDeleteSavedTabTitle;

  /// No description provided for @terminalDeleteSavedTabMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete “{name}”? Already open terminal sessions will not be affected.'**
  String terminalDeleteSavedTabMessage(Object name);

  /// No description provided for @terminalRunSavedCommands.
  ///
  /// In en, this message translates to:
  /// **'Run saved commands right after opening'**
  String get terminalRunSavedCommands;

  /// No description provided for @terminalRunSavedCommandsNote.
  ///
  /// In en, this message translates to:
  /// **'The commands run one after another per pane.'**
  String get terminalRunSavedCommandsNote;

  /// No description provided for @terminalOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Opening failed: {error}'**
  String terminalOpenFailed(String error);

  /// No description provided for @terminalAutoRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Automatic execution failed: {error}'**
  String terminalAutoRunFailed(String error);

  /// No description provided for @terminalRestartTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart terminal session?'**
  String get terminalRestartTitle;

  /// No description provided for @terminalRestartMessage.
  ///
  /// In en, this message translates to:
  /// **'The running process is terminated in a controlled manner and the session is restarted immediately. The previous terminal output is reset; unsent commands are preserved.'**
  String get terminalRestartMessage;

  /// No description provided for @terminalRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get terminalRestart;

  /// No description provided for @terminalRestartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restart the session: {error}'**
  String terminalRestartFailed(String error);

  /// No description provided for @terminalRenameTab.
  ///
  /// In en, this message translates to:
  /// **'Rename tab'**
  String get terminalRenameTab;

  /// No description provided for @terminalSaveTab.
  ///
  /// In en, this message translates to:
  /// **'Save tab'**
  String get terminalSaveTab;

  /// No description provided for @terminalRenameTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename terminal tab'**
  String get terminalRenameTabTitle;

  /// No description provided for @terminalFieldTabName.
  ///
  /// In en, this message translates to:
  /// **'Tab name'**
  String get terminalFieldTabName;

  /// No description provided for @terminalRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get terminalRename;

  /// No description provided for @terminalCloseTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Close terminal tab?'**
  String get terminalCloseTabTitle;

  /// No description provided for @terminalCloseTabMessage.
  ///
  /// In en, this message translates to:
  /// **'All running sessions of this tab will be terminated.'**
  String get terminalCloseTabMessage;

  /// No description provided for @terminalCloseTab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get terminalCloseTab;

  /// No description provided for @terminalCloseTabFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not close the tab: {error}'**
  String terminalCloseTabFailed(String error);

  /// No description provided for @terminalTrueColorTooltip.
  ///
  /// In en, this message translates to:
  /// **'xterm-256color with 24-bit true color'**
  String get terminalTrueColorTooltip;

  /// No description provided for @terminalAlternateScreenActive.
  ///
  /// In en, this message translates to:
  /// **'Alternate screen active'**
  String get terminalAlternateScreenActive;

  /// No description provided for @terminalMouseControlActive.
  ///
  /// In en, this message translates to:
  /// **'Terminal mouse control active'**
  String get terminalMouseControlActive;

  /// No description provided for @terminalCommandBlocksCount.
  ///
  /// In en, this message translates to:
  /// **'Show command history and output ({count})'**
  String terminalCommandBlocksCount(int count);

  /// No description provided for @terminalSplitLeftRight.
  ///
  /// In en, this message translates to:
  /// **'Split active window left/right'**
  String get terminalSplitLeftRight;

  /// No description provided for @terminalSplitTopBottom.
  ///
  /// In en, this message translates to:
  /// **'Split active window top/bottom'**
  String get terminalSplitTopBottom;

  /// No description provided for @terminalClosePane.
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get terminalClosePane;

  /// No description provided for @terminalCloseRunningPaneTitle.
  ///
  /// In en, this message translates to:
  /// **'Close running terminal?'**
  String get terminalCloseRunningPaneTitle;

  /// No description provided for @terminalCloseRunningPaneMessage.
  ///
  /// In en, this message translates to:
  /// **'The running session will be terminated.'**
  String get terminalCloseRunningPaneMessage;

  /// No description provided for @terminalCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get terminalCancel;

  /// No description provided for @terminalRestoreSplitView.
  ///
  /// In en, this message translates to:
  /// **'Restore split view'**
  String get terminalRestoreSplitView;

  /// No description provided for @terminalMaximizePane.
  ///
  /// In en, this message translates to:
  /// **'Maximize terminal pane'**
  String get terminalMaximizePane;

  /// No description provided for @terminalDecreaseFontSize.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get terminalDecreaseFontSize;

  /// No description provided for @terminalIncreaseFontSize.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get terminalIncreaseFontSize;

  /// No description provided for @terminalJumpToOutput.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest output'**
  String get terminalJumpToOutput;

  /// No description provided for @terminalNoMatches.
  ///
  /// In en, this message translates to:
  /// **'0 matches'**
  String get terminalNoMatches;

  /// No description provided for @terminalSearchScrollback.
  ///
  /// In en, this message translates to:
  /// **'Search scrollback'**
  String get terminalSearchScrollback;

  /// No description provided for @terminalPreviousMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get terminalPreviousMatch;

  /// No description provided for @terminalNextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get terminalNextMatch;

  /// No description provided for @terminalCommandBlocks.
  ///
  /// In en, this message translates to:
  /// **'Command blocks'**
  String get terminalCommandBlocks;

  /// No description provided for @terminalNotWhileRunning.
  ///
  /// In en, this message translates to:
  /// **'Not possible while a command is running'**
  String get terminalNotWhileRunning;

  /// No description provided for @terminalClearCommandBlocks.
  ///
  /// In en, this message translates to:
  /// **'Clear command blocks'**
  String get terminalClearCommandBlocks;

  /// No description provided for @terminalNoCommandsYet.
  ///
  /// In en, this message translates to:
  /// **'No commands sent through Terminal Master yet.'**
  String get terminalNoCommandsYet;

  /// No description provided for @terminalSavedCommands.
  ///
  /// In en, this message translates to:
  /// **'Saved commands'**
  String get terminalSavedCommands;

  /// No description provided for @terminalFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get terminalFilterAll;

  /// No description provided for @terminalFilterCurrentSession.
  ///
  /// In en, this message translates to:
  /// **'Current session'**
  String get terminalFilterCurrentSession;

  /// No description provided for @terminalRunNow.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get terminalRunNow;

  /// No description provided for @terminalMoreActionsShort.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get terminalMoreActionsShort;

  /// No description provided for @terminalRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Execution failed: {error}'**
  String terminalRunFailed(String error);

  /// No description provided for @terminalSavedCommandSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{timestamp} · Exit {exitCode}'**
  String terminalSavedCommandSubtitle(String timestamp, String exitCode);

  /// No description provided for @terminalOutputTruncated.
  ///
  /// In en, this message translates to:
  /// **'Output was truncated after {limit} characters.'**
  String terminalOutputTruncated(int limit);

  /// No description provided for @terminalLabelCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get terminalLabelCommand;

  /// No description provided for @terminalLabelOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get terminalLabelOutput;

  /// No description provided for @terminalExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get terminalExport;

  /// No description provided for @terminalExportCommandBlock.
  ///
  /// In en, this message translates to:
  /// **'Export command block'**
  String get terminalExportCommandBlock;

  /// No description provided for @terminalExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String terminalExportFailed(String error);

  /// No description provided for @terminalStatusRunningBlock.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get terminalStatusRunningBlock;

  /// No description provided for @terminalStatusSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded (exit 0)'**
  String get terminalStatusSucceeded;

  /// No description provided for @terminalStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed (exit {exitCode})'**
  String terminalStatusFailed(String exitCode);

  /// No description provided for @terminalStatusInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get terminalStatusInterrupted;

  /// No description provided for @terminalOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get terminalOpenLink;

  /// No description provided for @terminalSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get terminalSelectAll;

  /// No description provided for @terminalSearchSelection.
  ///
  /// In en, this message translates to:
  /// **'Search selection'**
  String get terminalSearchSelection;

  /// No description provided for @terminalClearOutput.
  ///
  /// In en, this message translates to:
  /// **'Clear output'**
  String get terminalClearOutput;

  /// No description provided for @terminalOpenLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link: {error}'**
  String terminalOpenLinkFailed(String error);

  /// No description provided for @terminalPasteMultilineTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste multiline text?'**
  String get terminalPasteMultilineTitle;

  /// No description provided for @terminalPasteMultilineMessage.
  ///
  /// In en, this message translates to:
  /// **'Line breaks can execute commands immediately. Check the content before pasting.'**
  String get terminalPasteMultilineMessage;

  /// No description provided for @terminalStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get terminalStatusReady;

  /// No description provided for @terminalStatusStarting.
  ///
  /// In en, this message translates to:
  /// **'Terminal is starting …'**
  String get terminalStatusStarting;

  /// No description provided for @terminalStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Terminal running'**
  String get terminalStatusActive;

  /// No description provided for @terminalStatusExited.
  ///
  /// In en, this message translates to:
  /// **'Process exited ({exitCode})'**
  String terminalStatusExited(String exitCode);

  /// No description provided for @terminalExitCodeUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get terminalExitCodeUnknown;

  /// No description provided for @terminalStatusStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Terminal could not be started: {error}'**
  String terminalStatusStartFailed(String error);

  /// No description provided for @terminalInfoShell.
  ///
  /// In en, this message translates to:
  /// **'Shell: {name}'**
  String terminalInfoShell(String name);

  /// No description provided for @terminalInfoDirectory.
  ///
  /// In en, this message translates to:
  /// **'Directory: {directory}'**
  String terminalInfoDirectory(String directory);

  /// No description provided for @terminalInfoStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String terminalInfoStatus(String status);

  /// No description provided for @hostKeyUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Unknown SSH server'**
  String get hostKeyUnknownTitle;

  /// No description provided for @hostKeyUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'No host key is stored for {endpoint} yet.\n\nType: {keyType}\nFingerprint: {fingerprint}\n\nCompare the fingerprint against a trusted source.'**
  String hostKeyUnknownMessage(
    String endpoint,
    String keyType,
    String fingerprint,
  );

  /// No description provided for @hostKeyTrustOnce.
  ///
  /// In en, this message translates to:
  /// **'Trust once'**
  String get hostKeyTrustOnce;

  /// No description provided for @hostKeyTrustPermanently.
  ///
  /// In en, this message translates to:
  /// **'Trust permanently'**
  String get hostKeyTrustPermanently;

  /// No description provided for @hostKeyChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'SSH host key changed'**
  String get hostKeyChangedTitle;

  /// No description provided for @hostKeyChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'The identity of {endpoint} does not match the stored host key. The connection was blocked.\n\nStored: {stored}\nReceived: {received}'**
  String hostKeyChangedMessage(String endpoint, String stored, String received);

  /// No description provided for @sshPageTitle.
  ///
  /// In en, this message translates to:
  /// **'SSH connections'**
  String get sshPageTitle;

  /// No description provided for @sshNoProfilesYet.
  ///
  /// In en, this message translates to:
  /// **'No SSH connections saved yet.'**
  String get sshNoProfilesYet;

  /// No description provided for @sshNoProfilesFound.
  ///
  /// In en, this message translates to:
  /// **'No SSH connections found.'**
  String get sshNoProfilesFound;

  /// No description provided for @sshSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search SSH connections'**
  String get sshSearchHint;

  /// No description provided for @sshClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get sshClearSearch;

  /// No description provided for @sshAddConnection.
  ///
  /// In en, this message translates to:
  /// **'Add connection'**
  String get sshAddConnection;

  /// No description provided for @sshTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get sshTest;

  /// No description provided for @sshEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get sshEdit;

  /// No description provided for @sshConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get sshConnect;

  /// No description provided for @sshSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sshSave;

  /// No description provided for @sshAuthenticationKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Authentication: SSH key'**
  String get sshAuthenticationKeyLabel;

  /// No description provided for @sshAuthenticationPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Authentication: password'**
  String get sshAuthenticationPasswordLabel;

  /// No description provided for @sshHostKeyConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Host key confirmed'**
  String get sshHostKeyConfirmed;

  /// No description provided for @sshHostKeyUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Host key not confirmed'**
  String get sshHostKeyUnconfirmed;

  /// No description provided for @sshProfileChangedReopen.
  ///
  /// In en, this message translates to:
  /// **'The SSH profile changed in the meantime. Open it again.'**
  String get sshProfileChangedReopen;

  /// No description provided for @sshProfileChangedDeleteAgain.
  ///
  /// In en, this message translates to:
  /// **'The SSH profile changed in the meantime. Delete it again.'**
  String get sshProfileChangedDeleteAgain;

  /// No description provided for @sshProfilesChangedRetry.
  ///
  /// In en, this message translates to:
  /// **'The SSH profiles changed in the meantime. Try again.'**
  String get sshProfilesChangedRetry;

  /// No description provided for @sshPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter an SSH password.'**
  String get sshPasswordRequired;

  /// No description provided for @sshSavedButCredentialCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'The profile was saved, but the previous credentials could not be removed from the keychain: {error}'**
  String sshSavedButCredentialCleanupFailed(String error);

  /// No description provided for @sshSaveFailedWithCleanup.
  ///
  /// In en, this message translates to:
  /// **'Could not save the SSH profile: {error}\nThe temporary credentials could not be removed either: {cleanupError}'**
  String sshSaveFailedWithCleanup(String error, String cleanupError);

  /// No description provided for @sshSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the SSH profile: {error}'**
  String sshSaveFailed(String error);

  /// No description provided for @sshDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete SSH connection?'**
  String get sshDeleteTitle;

  /// No description provided for @sshDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}” including its stored credentials?'**
  String sshDeleteMessage(String name);

  /// No description provided for @sshDeletedButCredentialCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'The profile was deleted, but the credentials could not be removed from the keychain: {error}'**
  String sshDeletedButCredentialCleanupFailed(String error);

  /// No description provided for @sshDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the SSH profile: {error}'**
  String sshDeleteFailed(String error);

  /// No description provided for @sshConnectionSucceeded.
  ///
  /// In en, this message translates to:
  /// **'SSH connection succeeded.'**
  String get sshConnectionSucceeded;

  /// No description provided for @sshConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'SSH connection failed: {error}'**
  String sshConnectionFailed(String error);

  /// No description provided for @sshExportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export encrypted SSH backup'**
  String get sshExportDialogTitle;

  /// No description provided for @sshImportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Import encrypted SSH backup'**
  String get sshImportDialogTitle;

  /// No description provided for @sshImportBackupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import encrypted backup'**
  String get sshImportBackupTooltip;

  /// No description provided for @sshExportBackupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export encrypted backup'**
  String get sshExportBackupTooltip;

  /// No description provided for @sshExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 SSH connection exported in encrypted form.} other{{count} SSH connections exported in encrypted form.}}'**
  String sshExportSuccess(int count);

  /// No description provided for @sshExportFailed.
  ///
  /// In en, this message translates to:
  /// **'SSH export failed: {error}'**
  String sshExportFailed(String error);

  /// No description provided for @sshBackupFilePickFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not choose the backup file: {error}'**
  String sshBackupFilePickFailed(String error);

  /// No description provided for @sshImportSummary.
  ///
  /// In en, this message translates to:
  /// **'{imported} imported, {replaced} replaced, {skipped} skipped.'**
  String sshImportSummary(int imported, int replaced, int skipped);

  /// No description provided for @sshImportFailed.
  ///
  /// In en, this message translates to:
  /// **'SSH import failed: {error}'**
  String sshImportFailed(String error);

  /// No description provided for @sshBackupFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The backup file is too large.'**
  String get sshBackupFileTooLarge;

  /// No description provided for @sshBackupDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted SSH backup'**
  String get sshBackupDialogTitle;

  /// No description provided for @sshBackupExportExplanation.
  ///
  /// In en, this message translates to:
  /// **'The backup contains the selected connections and their passwords or key passphrases. Private key files are not embedded. The backup is protected with Argon2id and AES-256-GCM.'**
  String get sshBackupExportExplanation;

  /// No description provided for @sshBackupPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get sshBackupPasswordLabel;

  /// No description provided for @sshBackupPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 12 characters'**
  String get sshBackupPasswordHelper;

  /// No description provided for @sshBackupPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 12 characters required.'**
  String get sshBackupPasswordTooShort;

  /// No description provided for @sshBackupPasswordRepeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat backup password'**
  String get sshBackupPasswordRepeatLabel;

  /// No description provided for @sshBackupPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get sshBackupPasswordMismatch;

  /// No description provided for @sshBackupPasswordNeeded.
  ///
  /// In en, this message translates to:
  /// **'Backup password required.'**
  String get sshBackupPasswordNeeded;

  /// No description provided for @sshBackupDecryptTitle.
  ///
  /// In en, this message translates to:
  /// **'Decrypt SSH backup'**
  String get sshBackupDecryptTitle;

  /// No description provided for @sshExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get sshExport;

  /// No description provided for @sshDecrypt.
  ///
  /// In en, this message translates to:
  /// **'Decrypt'**
  String get sshDecrypt;

  /// No description provided for @sshImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get sshImport;

  /// No description provided for @sshSelectAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Select at least one connection.'**
  String get sshSelectAtLeastOne;

  /// No description provided for @sshImportReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review SSH import'**
  String get sshImportReviewTitle;

  /// No description provided for @sshKeyShort.
  ///
  /// In en, this message translates to:
  /// **'SSH key'**
  String get sshKeyShort;

  /// No description provided for @sshPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get sshPasswordShort;

  /// No description provided for @sshImportDuplicateEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Duplicate endpoint in backup'**
  String get sshImportDuplicateEndpoint;

  /// No description provided for @sshImportExistingFound.
  ///
  /// In en, this message translates to:
  /// **'Existing connection found'**
  String get sshImportExistingFound;

  /// No description provided for @sshImportNewConnection.
  ///
  /// In en, this message translates to:
  /// **'New connection'**
  String get sshImportNewConnection;

  /// No description provided for @sshImportHostKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: host key differs'**
  String get sshImportHostKeyWarning;

  /// No description provided for @sshImportSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get sshImportSkip;

  /// No description provided for @sshImportReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get sshImportReplace;

  /// No description provided for @sshImportNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get sshImportNew;

  /// No description provided for @sshImportAsCopy.
  ///
  /// In en, this message translates to:
  /// **'As copy'**
  String get sshImportAsCopy;

  /// No description provided for @sshEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit SSH connection'**
  String get sshEditTitle;

  /// No description provided for @sshAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add SSH connection'**
  String get sshAddTitle;

  /// No description provided for @sshFieldDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get sshFieldDisplayName;

  /// No description provided for @sshFieldHost.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get sshFieldHost;

  /// No description provided for @sshFieldPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get sshFieldPort;

  /// No description provided for @sshFieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get sshFieldUsername;

  /// No description provided for @sshFieldAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get sshFieldAuthentication;

  /// No description provided for @sshPortRange.
  ///
  /// In en, this message translates to:
  /// **'Port must be between 1 and 65535.'**
  String get sshPortRange;

  /// No description provided for @sshAuthenticationKeyDesktop.
  ///
  /// In en, this message translates to:
  /// **'SSH key (desktop)'**
  String get sshAuthenticationKeyDesktop;

  /// No description provided for @sshFieldPrivateKeyFile.
  ///
  /// In en, this message translates to:
  /// **'Private key file'**
  String get sshFieldPrivateKeyFile;

  /// No description provided for @sshPickKeyFile.
  ///
  /// In en, this message translates to:
  /// **'Select key file'**
  String get sshPickKeyFile;

  /// No description provided for @sshPrivateKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a private key file.'**
  String get sshPrivateKeyRequired;

  /// No description provided for @sshClearStoredPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Remove stored passphrase'**
  String get sshClearStoredPassphrase;

  /// No description provided for @sshKeyPassphraseKeep.
  ///
  /// In en, this message translates to:
  /// **'Key passphrase (leave empty to keep)'**
  String get sshKeyPassphraseKeep;

  /// No description provided for @sshKeyPassphraseOptional.
  ///
  /// In en, this message translates to:
  /// **'Key passphrase (optional)'**
  String get sshKeyPassphraseOptional;

  /// No description provided for @sshPasswordKeep.
  ///
  /// In en, this message translates to:
  /// **'New password (leave empty to keep)'**
  String get sshPasswordKeep;

  /// No description provided for @sshPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get sshPasswordLabel;

  /// No description provided for @sshShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get sshShowPassword;

  /// No description provided for @sshHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get sshHidePassword;

  /// No description provided for @sshPasswordNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'The password must not be empty.'**
  String get sshPasswordNotEmpty;

  /// No description provided for @sshCredentialStorageNote.
  ///
  /// In en, this message translates to:
  /// **'Passwords and key passphrases are stored exclusively in the operating system keychain. Private keys stay in the selected file.'**
  String get sshCredentialStorageNote;

  /// No description provided for @sshFieldNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'{label} must not be empty.'**
  String sshFieldNotEmpty(String label);

  /// No description provided for @sshFieldInvalidControlCharacters.
  ///
  /// In en, this message translates to:
  /// **'{label} contains invalid control characters.'**
  String sshFieldInvalidControlCharacters(String label);

  /// No description provided for @sshKeyFilesDesktopOnly.
  ///
  /// In en, this message translates to:
  /// **'SSH key files are currently only supported on desktop platforms, because mobile file pickers do not provide durably usable paths.'**
  String get sshKeyFilesDesktopOnly;

  /// No description provided for @sshPickPrivateKeyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Select private SSH key file'**
  String get sshPickPrivateKeyDialogTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get settingsSectionTerminal;

  /// No description provided for @settingsDefaultShellLabel.
  ///
  /// In en, this message translates to:
  /// **'Default shell'**
  String get settingsDefaultShellLabel;

  /// No description provided for @settingsDefaultShellHelper.
  ///
  /// In en, this message translates to:
  /// **'Used for new terminal tabs.'**
  String get settingsDefaultShellHelper;

  /// No description provided for @settingsDefaultShellSaved.
  ///
  /// In en, this message translates to:
  /// **'Default shell saved.'**
  String get settingsDefaultShellSaved;

  /// No description provided for @settingsDefaultShellSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the default shell: {error}'**
  String settingsDefaultShellSaveFailed(String error);

  /// No description provided for @settingsSectionCommandBuilder.
  ///
  /// In en, this message translates to:
  /// **'Command Builder'**
  String get settingsSectionCommandBuilder;

  /// No description provided for @settingsYamlDirectoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Default YAML folder'**
  String get settingsYamlDirectoryLabel;

  /// No description provided for @settingsYamlDirectoryHelper.
  ///
  /// In en, this message translates to:
  /// **'Templates are loaded from this folder.'**
  String get settingsYamlDirectoryHelper;

  /// No description provided for @settingsSelectYamlDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select YAML folder'**
  String get settingsSelectYamlDirectory;

  /// No description provided for @settingsYamlDirectoryMissing.
  ///
  /// In en, this message translates to:
  /// **'The selected folder does not exist.'**
  String get settingsYamlDirectoryMissing;

  /// No description provided for @settingsYamlDirectorySaved.
  ///
  /// In en, this message translates to:
  /// **'Default YAML folder saved.'**
  String get settingsYamlDirectorySaved;

  /// No description provided for @settingsYamlDirectorySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the default YAML folder: {error}'**
  String settingsYamlDirectorySaveFailed(String error);

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsSectionLanguage;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsLanguageHelper.
  ///
  /// In en, this message translates to:
  /// **'Takes effect immediately.'**
  String get settingsLanguageHelper;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageSaved.
  ///
  /// In en, this message translates to:
  /// **'Language saved.'**
  String get settingsLanguageSaved;

  /// No description provided for @settingsLanguageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the language: {error}'**
  String settingsLanguageSaveFailed(String error);

  /// No description provided for @configEditorNew.
  ///
  /// In en, this message translates to:
  /// **'New configuration'**
  String get configEditorNew;

  /// No description provided for @configEditorEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit configuration'**
  String get configEditorEdit;

  /// No description provided for @configEditorCreate.
  ///
  /// In en, this message translates to:
  /// **'Create configuration'**
  String get configEditorCreate;

  /// No description provided for @configEditorCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get configEditorCommand;

  /// No description provided for @configEditorDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get configEditorDisplayName;

  /// No description provided for @configEditorDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get configEditorDescription;

  /// No description provided for @configEditorHelpText.
  ///
  /// In en, this message translates to:
  /// **'Help text'**
  String get configEditorHelpText;

  /// No description provided for @configEditorParameters.
  ///
  /// In en, this message translates to:
  /// **'Input elements'**
  String get configEditorParameters;

  /// No description provided for @configEditorAddParameter.
  ///
  /// In en, this message translates to:
  /// **'Add element'**
  String get configEditorAddParameter;

  /// No description provided for @configEditorNoParameters.
  ///
  /// In en, this message translates to:
  /// **'No input elements yet.'**
  String get configEditorNoParameters;

  /// No description provided for @configEditorElementName.
  ///
  /// In en, this message translates to:
  /// **'Element name'**
  String get configEditorElementName;

  /// No description provided for @configEditorElementType.
  ///
  /// In en, this message translates to:
  /// **'Element type'**
  String get configEditorElementType;

  /// No description provided for @configEditorTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text field'**
  String get configEditorTypeText;

  /// No description provided for @configEditorTypeOptions.
  ///
  /// In en, this message translates to:
  /// **'Dropdown'**
  String get configEditorTypeOptions;

  /// No description provided for @configEditorTypeBoolean.
  ///
  /// In en, this message translates to:
  /// **'Checkbox'**
  String get configEditorTypeBoolean;

  /// No description provided for @configEditorTypeFilepath.
  ///
  /// In en, this message translates to:
  /// **'File picker'**
  String get configEditorTypeFilepath;

  /// No description provided for @configEditorTypeTextList.
  ///
  /// In en, this message translates to:
  /// **'Text list'**
  String get configEditorTypeTextList;

  /// No description provided for @configEditorTypeButton.
  ///
  /// In en, this message translates to:
  /// **'Button'**
  String get configEditorTypeButton;

  /// No description provided for @configEditorFlag.
  ///
  /// In en, this message translates to:
  /// **'Command-line flag'**
  String get configEditorFlag;

  /// No description provided for @configEditorRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get configEditorRequired;

  /// No description provided for @configEditorDefault.
  ///
  /// In en, this message translates to:
  /// **'Default value'**
  String get configEditorDefault;

  /// No description provided for @configEditorOptions.
  ///
  /// In en, this message translates to:
  /// **'Dropdown options'**
  String get configEditorOptions;

  /// No description provided for @configEditorAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get configEditorAddOption;

  /// No description provided for @configEditorOptionValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get configEditorOptionValue;

  /// No description provided for @configEditorOptionDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get configEditorOptionDescription;

  /// No description provided for @configEditorRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get configEditorRemove;

  /// No description provided for @configEditorMode.
  ///
  /// In en, this message translates to:
  /// **'Select files or folders'**
  String get configEditorMode;

  /// No description provided for @configEditorDependencies.
  ///
  /// In en, this message translates to:
  /// **'Depends on'**
  String get configEditorDependencies;

  /// No description provided for @configEditorConflicts.
  ///
  /// In en, this message translates to:
  /// **'Conflicts with'**
  String get configEditorConflicts;

  /// No description provided for @configEditorVisibleWhen.
  ///
  /// In en, this message translates to:
  /// **'Visible when'**
  String get configEditorVisibleWhen;

  /// No description provided for @configEditorRequiredWhen.
  ///
  /// In en, this message translates to:
  /// **'Required when'**
  String get configEditorRequiredWhen;

  /// No description provided for @configEditorAddCondition.
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get configEditorAddCondition;

  /// No description provided for @configEditorConditionParameter.
  ///
  /// In en, this message translates to:
  /// **'Other element'**
  String get configEditorConditionParameter;

  /// No description provided for @configEditorConditionOperator.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get configEditorConditionOperator;

  /// No description provided for @configEditorConditionEquals.
  ///
  /// In en, this message translates to:
  /// **'Equals'**
  String get configEditorConditionEquals;

  /// No description provided for @configEditorConditionIn.
  ///
  /// In en, this message translates to:
  /// **'One of these values'**
  String get configEditorConditionIn;

  /// No description provided for @configEditorConditionActive.
  ///
  /// In en, this message translates to:
  /// **'Is active'**
  String get configEditorConditionActive;

  /// No description provided for @configEditorConditionValue.
  ///
  /// In en, this message translates to:
  /// **'Value(s), comma separated for “one of”'**
  String get configEditorConditionValue;

  /// No description provided for @configEditorMatchAny.
  ///
  /// In en, this message translates to:
  /// **'Match any condition'**
  String get configEditorMatchAny;

  /// No description provided for @configEditorSave.
  ///
  /// In en, this message translates to:
  /// **'Save YAML'**
  String get configEditorSave;

  /// No description provided for @configEditorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save configuration: {error}'**
  String configEditorSaveFailed(String error);

  /// No description provided for @configEditorSaved.
  ///
  /// In en, this message translates to:
  /// **'Configuration saved.'**
  String get configEditorSaved;

  /// No description provided for @configEditorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Fix the configuration errors before saving.'**
  String get configEditorInvalid;

  /// No description provided for @configEditorDeleteElement.
  ///
  /// In en, this message translates to:
  /// **'Delete element'**
  String get configEditorDeleteElement;

  /// No description provided for @configEditorNewFileExists.
  ///
  /// In en, this message translates to:
  /// **'A configuration with this command already exists.'**
  String get configEditorNewFileExists;

  /// No description provided for @configEditorDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get configEditorDiscardTitle;

  /// No description provided for @configEditorDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get configEditorDiscard;

  /// No description provided for @configEditorDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'Your changes will be lost if you leave this editor.'**
  String get configEditorDiscardMessage;

  /// No description provided for @configEditorExecutable.
  ///
  /// In en, this message translates to:
  /// **'Executable'**
  String get configEditorExecutable;

  /// No description provided for @configEditorArguments.
  ///
  /// In en, this message translates to:
  /// **'Arguments'**
  String get configEditorArguments;

  /// No description provided for @configEditorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Prefix'**
  String get configEditorPrefix;

  /// No description provided for @configEditorSuffix.
  ///
  /// In en, this message translates to:
  /// **'Suffix'**
  String get configEditorSuffix;

  /// No description provided for @configEditorExample.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get configEditorExample;

  /// No description provided for @configEditorNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get configEditorNote;

  /// No description provided for @configEditorLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get configEditorLabel;

  /// No description provided for @configEditorMustDiffer.
  ///
  /// In en, this message translates to:
  /// **'Must be different from dependent values'**
  String get configEditorMustDiffer;

  /// No description provided for @configEditorPlacement.
  ///
  /// In en, this message translates to:
  /// **'Value placement'**
  String get configEditorPlacement;

  /// No description provided for @configEditorJoin.
  ///
  /// In en, this message translates to:
  /// **'Flag and value formatting'**
  String get configEditorJoin;

  /// No description provided for @configEditorAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get configEditorAutomatic;

  /// No description provided for @configEditorBeforeCommand.
  ///
  /// In en, this message translates to:
  /// **'Before command'**
  String get configEditorBeforeCommand;

  /// No description provided for @configEditorArgument.
  ///
  /// In en, this message translates to:
  /// **'Command argument'**
  String get configEditorArgument;

  /// No description provided for @configEditorPipeline.
  ///
  /// In en, this message translates to:
  /// **'Pipeline'**
  String get configEditorPipeline;

  /// No description provided for @configEditorSeparated.
  ///
  /// In en, this message translates to:
  /// **'Separated'**
  String get configEditorSeparated;

  /// No description provided for @configEditorAttached.
  ///
  /// In en, this message translates to:
  /// **'Attached'**
  String get configEditorAttached;

  /// No description provided for @configEditorModeFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get configEditorModeFile;

  /// No description provided for @configEditorModeDirectory.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get configEditorModeDirectory;

  /// No description provided for @configEditorModeAny.
  ///
  /// In en, this message translates to:
  /// **'File or directory'**
  String get configEditorModeAny;

  /// No description provided for @mainCreateFileType.
  ///
  /// In en, this message translates to:
  /// **'Choose what to create'**
  String get mainCreateFileType;

  /// No description provided for @mainCommandConfigDescription.
  ///
  /// In en, this message translates to:
  /// **'Define input fields and conditions for one command.'**
  String get mainCommandConfigDescription;

  /// No description provided for @mainBatchConfigDescription.
  ///
  /// In en, this message translates to:
  /// **'Create an empty command list and add commands later.'**
  String get mainBatchConfigDescription;

  /// No description provided for @batchCreateFile.
  ///
  /// In en, this message translates to:
  /// **'New batch YAML'**
  String get batchCreateFile;

  /// No description provided for @batchCreateFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Create batch file'**
  String get batchCreateFileTitle;

  /// No description provided for @batchCreateFileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get batchCreateFileName;

  /// No description provided for @batchFileCreated.
  ///
  /// In en, this message translates to:
  /// **'Empty batch file created.'**
  String get batchFileCreated;

  /// No description provided for @batchCreateFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create batch file: {error}'**
  String batchCreateFileFailed(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
