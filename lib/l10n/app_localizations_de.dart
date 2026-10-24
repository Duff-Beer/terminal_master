// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonDescription => 'Beschreibung';

  @override
  String buildFailurePipelineNeedsCommand(String parameter) {
    return 'Pipeline „$parameter“ benötigt ein Kommando.';
  }

  @override
  String get buildFailureCommandIsEmpty =>
      'Das auszuführende Kommando ist leer.';

  @override
  String get buildFailureInvalidButtonAction => 'Ungültige Button-Aktion.';

  @override
  String buildFailureRequiredParameterMissing(String parameter) {
    return 'Erforderlicher Parameter „$parameter“ fehlt.';
  }

  @override
  String buildFailureParameterRequiresOther(String parameter, String other) {
    return 'Parameter „$parameter“ erfordert „$other“.';
  }

  @override
  String buildFailureParameterConflictsWithOther(
    String parameter,
    String other,
  ) {
    return 'Parameter „$parameter“ kann nicht mit „$other“ verwendet werden.';
  }

  @override
  String buildFailureParameterMustDifferFromOther(
    String parameter,
    String other,
  ) {
    return 'Parameter „$parameter“ muss sich von „$other“ unterscheiden.';
  }

  @override
  String buildFailureInvalidOptionValue(String parameter) {
    return 'Parameter „$parameter“ enthält einen ungültigen Optionswert.';
  }

  @override
  String get buildFailureDdInputEqualsOutput =>
      'Eingabe und Ausgabe von dd müssen sich unterscheiden.';

  @override
  String buildFailureMultipleValuesNotAttachable(String parameter) {
    return 'Parameter „$parameter“ kann mehrere Werte nicht direkt an ein Flag anhängen.';
  }

  @override
  String buildFailureInvalidConfigurationValue(String detail) {
    return 'Ungültiger Konfigurationswert: $detail';
  }

  @override
  String buildFailureParameterMustBeList(String parameter) {
    return 'Parameter „$parameter“ muss eine Liste enthalten.';
  }

  @override
  String get buildFailureControlCharactersNotAllowed =>
      'Kommandoargumente dürfen keine Steuerzeichen enthalten.';

  @override
  String get buildFailureUnsafeWindowsCharacter =>
      'Die Windows-Shell unterstützt dieses Zeichen in Eingabewerten nicht sicher.';

  @override
  String get optionStoreValueAndDescriptionRequired =>
      'Wert und Beschreibung dürfen nicht leer sein.';

  @override
  String get optionStoreControlCharactersNotAllowed =>
      'Wert und Beschreibung dürfen keine Steuerzeichen enthalten.';

  @override
  String get optionStoreFileChangedMeanwhile =>
      'Die YAML-Datei wurde zwischenzeitlich geändert. Öffne sie erneut.';

  @override
  String optionStoreDuplicateOptionValue(String value) {
    return 'Der Optionswert „$value“ ist bereits vorhanden.';
  }

  @override
  String get optionStoreNewEntryNotValid =>
      'Der neue Eintrag konnte nicht validiert werden.';

  @override
  String optionStoreOptionValueNotFound(String value) {
    return 'Der Optionswert „$value“ wurde nicht gefunden.';
  }

  @override
  String get optionStoreLastOptionCannotBeDeleted =>
      'Der letzte Optionswert kann nicht gelöscht werden.';

  @override
  String get optionStoreUnsupportedOptionListFormat =>
      'Die Optionsliste verwendet ein nicht unterstütztes YAML-Format.';

  @override
  String get optionStoreEntryNotFullyDeleted =>
      'Der Eintrag konnte nicht vollständig gelöscht werden.';

  @override
  String get optionStoreInvalidYamlRoot => 'Die YAML-Wurzel ist ungültig.';

  @override
  String get optionStoreMissingParameterList => 'Die Parameterliste fehlt.';

  @override
  String optionStoreOptionsParameterNotFound(String name) {
    return 'Der Optionsparameter „$name“ wurde nicht gefunden.';
  }

  @override
  String get optionStoreMissingOptionList => 'Die Optionsliste fehlt.';

  @override
  String optionStoreMissingField(String field) {
    return 'Das Feld „$field“ fehlt.';
  }

  @override
  String get batchStoreTitleAndCommandRequired =>
      'Titel und Befehl dürfen nicht leer sein.';

  @override
  String get batchStoreUnsupportedCommandListFormat =>
      'Die Befehlsliste verwendet ein nicht unterstütztes YAML-Format.';

  @override
  String get batchStoreNewCommandNotValid =>
      'Der neue Befehl konnte nicht validiert werden.';

  @override
  String get batchStoreCommandToDeleteNotFound =>
      'Der zu löschende Befehl wurde nicht gefunden.';

  @override
  String get batchStoreCommandNotFullyDeleted =>
      'Der Befehl konnte nicht vollständig gelöscht werden.';

  @override
  String get batchStoreInvalidYamlRoot => 'Die YAML-Wurzel ist ungültig.';

  @override
  String get batchStoreMissingCommandList => 'Die Befehlsliste fehlt.';

  @override
  String get batchStoreFileChangedMeanwhile =>
      'Die YAML-Datei wurde zwischenzeitlich geändert. Öffne sie erneut.';

  @override
  String batchStoreMissingField(String field) {
    return 'Das Feld „$field“ fehlt.';
  }

  @override
  String get tabFailureUnknownProfile => 'Unbekanntes Profil.';

  @override
  String tabFailureSavedTabsUnreadable(String detail) {
    return 'Gespeicherte Tabs konnten nicht geladen werden: $detail';
  }

  @override
  String get tabFailureSshTabsCannotBeSnapshotted =>
      'SSH-Terminal-Tabs können aus Sicherheitsgründen nicht als Terminal-Snapshot gespeichert werden.';

  @override
  String get tabFailureNameMustNotBeEmpty => 'Der Name darf nicht leer sein.';

  @override
  String get tabFailureSavedTabChangedMeanwhile =>
      'Dieser gespeicherte Tab wurde zwischenzeitlich geändert. Öffne die aktuelle Version erneut.';

  @override
  String get tabFailureInvalidTabName => 'Ungültiger Terminal-Tabname.';

  @override
  String get tabFailureIntegratedTerminalUnavailable =>
      'Das integrierte Terminal ist nicht verfügbar.';

  @override
  String tabFailureShellProfileUnavailable(String profile) {
    return 'Das Shell-Profil „$profile“ ist nicht verfügbar.';
  }

  @override
  String get authFailurePassphraseTooLong => 'Die Key-Passphrase ist zu lang.';

  @override
  String get authFailurePassphraseRequired =>
      'Der private SSH-Schlüssel benötigt eine Passphrase.';

  @override
  String get authFailureNoPrivateKeyInFile =>
      'Die Datei enthält keinen privaten SSH-Schlüssel.';

  @override
  String get authFailureInvalidKeyOrPassphrase =>
      'Der private SSH-Schlüssel oder seine Passphrase ist ungültig oder wird nicht unterstützt.';

  @override
  String get authFailureInvalidOrUnsupportedKey =>
      'Der private SSH-Schlüssel ist ungültig oder wird nicht unterstützt.';

  @override
  String get authFailureKeyFileTooLarge =>
      'Die private Schlüsseldatei ist zu groß.';

  @override
  String get authFailureKeyFileUnreadable =>
      'Die private Schlüsseldatei konnte nicht gelesen werden.';

  @override
  String get authFailureKeyFileNotUtf8 =>
      'Die private Schlüsseldatei ist keine gültige UTF-8-Textdatei.';

  @override
  String authFailureNoStoredPassword(String profile) {
    return 'Für „$profile“ ist kein Passwort im Schlüsselbund gespeichert.';
  }

  @override
  String authFailureNoPrivateKeyConfigured(String profile) {
    return 'Für „$profile“ ist keine private Schlüsseldatei konfiguriert.';
  }

  @override
  String get backupFailureInvalidAuthenticationInBackup =>
      'Das SSH-Backup enthält eine ungültige Authentifizierung.';

  @override
  String get backupFailureInvalidDataInBackup =>
      'Das SSH-Backup enthält ungültige Daten.';

  @override
  String get backupFailureSelectAtLeastOneConnection =>
      'Wähle mindestens eine SSH-Verbindung aus.';

  @override
  String get backupFailureTooManyConnectionsSelected =>
      'Zu viele SSH-Verbindungen ausgewählt.';

  @override
  String get backupFailureBackupPasswordTooShort =>
      'Das Backup-Passwort muss mindestens 12 Zeichen lang sein.';

  @override
  String backupFailureCredentialsNotStored(String profile) {
    return 'Für „$profile“ sind die benötigten Anmeldedaten nicht gespeichert.';
  }

  @override
  String get backupFailureFileTooLarge => 'Die Backup-Datei ist zu groß.';

  @override
  String get backupFailureBackupPasswordMissing => 'Das Backup-Passwort fehlt.';

  @override
  String get backupFailureInvalidBackupParameters =>
      'Ungültige Backup-Parameter.';

  @override
  String get backupFailureInvalidBackupCryptoData =>
      'Ungültige Backup-Kryptodaten.';

  @override
  String get backupFailureInvalidBackupContent => 'Ungültiger Backup-Inhalt.';

  @override
  String get backupFailureInvalidConnectionCount =>
      'Das Backup enthält eine ungültige Anzahl Verbindungen.';

  @override
  String get backupFailureInvalidConnections =>
      'Das Backup enthält ungültige Verbindungen.';

  @override
  String get backupFailureWrongPasswordOrTampered =>
      'Das Backup-Passwort ist falsch oder die Datei wurde verändert.';

  @override
  String get backupFailureConnectionNotExportable =>
      'Eine SSH-Verbindung enthält nicht exportierbare Daten.';

  @override
  String get backupFailureUnknownBackupFormat =>
      'Unbekanntes SSH-Backupformat.';

  @override
  String backupFailureProfileReplacedTwice(String profile) {
    return 'Das Profil „$profile“ kann nicht mehrfach ersetzt werden.';
  }

  @override
  String get backupFailureProfileToReplaceNotFound =>
      'Ein zu ersetzendes SSH-Profil wurde nicht gefunden.';

  @override
  String get backupFailureProfilesChangedDuringImport =>
      'Die SSH-Profile wurden während des Imports geändert. Starte den Import erneut.';

  @override
  String backupFailureImportFailedWithCleanup(String error, String detail) {
    return '$error\nZusätzlich konnten temporäre Schlüsselbund-Einträge nicht entfernt werden: $detail';
  }

  @override
  String importWarningPreviousPasswordNotRemoved(String detail) {
    return 'Ein vorheriges Passwort konnte nicht entfernt werden: $detail';
  }

  @override
  String get persistedInvalidSavedCommand => 'Ungültiger gespeicherter Befehl.';

  @override
  String get persistedInvalidSavedPane =>
      'Ungültige gespeicherte Terminal-Pane.';

  @override
  String get persistedInvalidSavedTab =>
      'Ungültiger gespeicherter Terminal-Tab.';

  @override
  String get persistedInvalidPaneTopology => 'Ungültige Pane-Topologie.';

  @override
  String get persistedInvalidSshAuthentication =>
      'Ungültige SSH-Authentifizierung.';

  @override
  String get persistedInvalidSshProfile => 'Ungültiges SSH-Verbindungsprofil.';

  @override
  String get persistedInvalidSshHostKey => 'Ungültiger SSH-Host-Key.';

  @override
  String get persistedInvalidSshProfileList => 'Ungültige SSH-Profilliste.';

  @override
  String serviceUnsupportedLink(String uri) {
    return 'Nicht unterstützter Link: $uri';
  }

  @override
  String get serviceLinksNotOpenableOnPlatform =>
      'Links werden auf dieser Plattform nicht geöffnet.';

  @override
  String get serviceTerminalDetectionUnsupported =>
      'Terminal-Erkennung wird auf dieser Plattform nicht unterstützt.';

  @override
  String get serviceSshProfileNotFound =>
      'Das SSH-Verbindungsprofil wurde nicht gefunden.';

  @override
  String get sessionFailureSessionNotRunning =>
      'Die Terminal-Sitzung läuft nicht.';

  @override
  String get sessionFailureTrackedCommandAlreadyRunning =>
      'In diesem Terminal läuft bereits ein getrackter Befehl.';

  @override
  String get sessionFailureNulNotAllowed => 'NUL ist nicht erlaubt.';

  @override
  String get sessionFailureProcessCouldNotBeTerminated =>
      'Der Terminal-Prozess konnte nicht beendet werden.';

  @override
  String get sessionFailureProcessDidNotExitInTime =>
      'Der Terminal-Prozess wurde nicht innerhalb des Zeitlimits beendet.';

  @override
  String get sessionFailureWindowsHomePathNotAscii =>
      'flutter_pty unterstützt unter Windows derzeit keine Benutzerpfade mit Nicht-ASCII-Zeichen. Verwende vorerst das externe Terminal.';

  @override
  String get sessionFailureShellExecutableEmpty =>
      'Das Shell-Programm darf nicht leer sein.';

  @override
  String get sessionFailureWindowsProfileNotAscii =>
      'flutter_pty unterstützt unter Windows derzeit nur ASCII-Zeichen in integrierten Shell-Profilen. Verwende vorerst das externe Terminal.';

  @override
  String configErrorAt(String file, String field, String reason) {
    return '$file: $field: $reason';
  }

  @override
  String get configReasonMustBeList => 'muss eine Liste sein';

  @override
  String get configReasonMustBeNonEmptyList =>
      'muss eine nicht leere Liste sein';

  @override
  String get configReasonMustBeObject => 'muss ein Objekt sein';

  @override
  String get configReasonMustBeText => 'muss Text enthalten';

  @override
  String get configReasonMustBeBoolean => 'muss true oder false sein';

  @override
  String get configReasonMustBeInteger => 'muss eine Ganzzahl sein';

  @override
  String get configReasonMustBeTextList => 'muss eine Textliste sein';

  @override
  String get configReasonMustBeTextOrBoolean =>
      'muss Text, true oder false sein';

  @override
  String get configReasonMustBeFilePickerMode =>
      'muss file, directory oder any sein';

  @override
  String get configReasonMustBeExecutionMode =>
      'muss automatic, before_command, argument oder pipeline sein';

  @override
  String get configReasonMustBeAttachmentMode =>
      'muss automatic, separated oder attached sein';

  @override
  String get configReasonOptionsParameterNeedsEntry =>
      'Optionsparameter benötigt mindestens einen Eintrag';

  @override
  String get configReasonButtonNeedsExecutable =>
      'Button benötigt ein ausführbares Programm';

  @override
  String get configReasonTypeMismatch =>
      'hat nicht den zum Parametertyp passenden Datentyp';

  @override
  String get configReasonNotInOptions => 'ist nicht in options enthalten';

  @override
  String configReasonDuplicateParameterName(String name) {
    return 'Parametername „$name“ ist doppelt vorhanden';
  }

  @override
  String configReasonDuplicateOptionValue(String value) {
    return 'Optionswert „$value“ ist doppelt vorhanden';
  }

  @override
  String configReasonUnknownParameterType(String type) {
    return 'unbekannter Parametertyp „$type“';
  }

  @override
  String configReasonUnknownParameterReference(String name) {
    return 'verweist auf unbekannten Parameter „$name“';
  }

  @override
  String configReasonUnknownFields(String fields) {
    return 'enthält unbekannte Felder: $fields';
  }

  @override
  String configReasonUnknownGroupFields(String fields) {
    return 'enthält unbekannte Gruppenfelder: $fields';
  }

  @override
  String get configReasonConditionSelfReference =>
      'Bedingung darf nicht auf den eigenen Parameter verweisen';

  @override
  String configReasonConditionValueTypeMismatch(String name) {
    return 'Bedingungswert passt nicht zum Typ von „$name“';
  }

  @override
  String configReasonConditionValueNotAnOption(String name) {
    return 'Bedingungswert ist keine Option von „$name“';
  }

  @override
  String get configReasonBothAllAndAny =>
      'darf nicht gleichzeitig all und any enthalten';

  @override
  String get configReasonNeedsAtLeastOneCondition =>
      'muss mindestens eine Bedingung enthalten';

  @override
  String get configReasonOnlyEqualsInOrActive =>
      'darf nur equals, in oder active verwenden';

  @override
  String configReasonUnsupportedSchemaVersion(String version) {
    return 'unterstützt wird nur Version $version';
  }

  @override
  String get configReasonFileNotFound => 'Datei wurde nicht gefunden';

  @override
  String configReasonFileUnreadable(String detail) {
    return 'Datei konnte nicht gelesen werden: $detail';
  }

  @override
  String configReasonInvalidYaml(String detail) {
    return 'ungültiges YAML: $detail';
  }

  @override
  String configItemBatchCommands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Befehle in dieser Datei',
      one: '1 Befehl in dieser Datei',
    );
    return '$_temp0';
  }

  @override
  String get configItemNoDescription => 'Keine Beschreibung';

  @override
  String configItemLoadError(String file) {
    return 'Fehler: $file';
  }

  @override
  String get configErrorTitle => 'Konfigurationsfehler';

  @override
  String get outputTitle => 'Command Output';

  @override
  String generatorAddOptionTitle(String parameter) {
    return 'Eintrag zu $parameter hinzufügen';
  }

  @override
  String get generatorFieldValue => 'Wert';

  @override
  String generatorOptionSaveFailed(String error) {
    return 'Eintrag konnte nicht gespeichert werden: $error';
  }

  @override
  String generatorOptionDeleteFailed(String error) {
    return 'Eintrag konnte nicht gelöscht werden: $error';
  }

  @override
  String generatorBuildFailed(String error) {
    return 'Fehler: $error';
  }

  @override
  String generatorExecuteFailed(String error) {
    return 'Fehler beim Ausführen: $error';
  }

  @override
  String generatorActionFailed(String error) {
    return 'Fehler bei der Aktion: $error';
  }

  @override
  String generatorCommandCopied(String command) {
    return 'Kommando in die Zwischenablage kopiert:\n$command';
  }

  @override
  String get generatorBuildCommand => 'Kommando erzeugen';

  @override
  String get generatorPreparing => 'Wird vorbereitet...';

  @override
  String get generatorInsertIntoTerminal => 'Ins Terminal einfügen';

  @override
  String get generatorRunCommand => 'Kommando ausführen';

  @override
  String get generatorIntegratedTerminal => 'Integriertes Terminal';

  @override
  String get generatorIntegratedTerminalOn =>
      'Befehl direkt in Terminal Master ausführen';

  @override
  String get generatorIntegratedTerminalOff =>
      'Konfigurierte externe Terminal-App verwenden';

  @override
  String get generatorNewExternalTerminal => 'Neues externes Terminal';

  @override
  String get pickDirectory => 'Verzeichnis auswählen';

  @override
  String get pickFileOrDirectory => 'Datei oder Verzeichnis auswählen';

  @override
  String get pickFile => 'Datei auswählen';

  @override
  String get listRemoveEntry => 'Eintrag entfernen';

  @override
  String get listAddEntry => 'Weiteren Eintrag hinzufügen';

  @override
  String get riskReasonRmDeletesPermanently =>
      'rm kann Dateien und Verzeichnisse dauerhaft löschen.';

  @override
  String get riskReasonDdOverwrites =>
      'dd kann Dateien, Datenträger und Partitionen überschreiben.';

  @override
  String get riskReasonForceOptionSkipsPrompts =>
      'Die Force-Option überspringt normale Schutzabfragen.';

  @override
  String get riskReasonElevatedPrivileges =>
      'Das Kommando wird mit erhöhten Rechten ausgeführt.';

  @override
  String get riskReasonBatchMayDeleteOrOverwrite =>
      'Mindestens ein Batch-Kommando kann Daten löschen oder überschreiben.';

  @override
  String get riskReasonBatchUsesForce =>
      'Mindestens ein Batch-Kommando verwendet eine Force-Option.';

  @override
  String get riskReasonBatchUsesElevatedPrivileges =>
      'Mindestens ein Batch-Kommando verwendet erhöhte Rechte.';

  @override
  String get confirmTitleStandard => 'Kommando prüfen';

  @override
  String get confirmTitleElevated => 'Erhöhte Rechte bestätigen';

  @override
  String get confirmTitleDestructive => 'Destruktives Kommando bestätigen';

  @override
  String get confirmRawConfigWarning =>
      'Diese Befehle stammen direkt aus einer YAML-Datei. Führe sie nur aus, wenn du die Datei und ihren Inhalt vertraust.';

  @override
  String confirmCommandsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Auszuführende Kommandos',
      one: 'Auszuführendes Kommando',
    );
    return '$_temp0';
  }

  @override
  String get confirmAcknowledgement =>
      'Ich habe das Kommando geprüft und verstehe das Risiko.';

  @override
  String get confirmRun => 'Ausführen';

  @override
  String get optionsPleaseSelect => 'Bitte auswählen';

  @override
  String get optionsNotUsed => 'Nicht verwenden';

  @override
  String get optionsSearchHint => 'Wert oder Beschreibung durchsuchen';

  @override
  String get optionsNoMatches => 'Keine Treffer';

  @override
  String get optionsAddEntry => 'Eintrag hinzufügen';

  @override
  String get optionsDeleteEntry => 'Eintrag löschen';

  @override
  String get optionsDeleteTitle => 'Eintrag löschen?';

  @override
  String optionsDeleteMessage(String value) {
    return 'Soll „$value“ dauerhaft aus der YAML-Datei gelöscht werden?';
  }

  @override
  String get mainTitle => 'Command Builder';

  @override
  String get mainSearchHint => 'Vorlagen durchsuchen';

  @override
  String get mainDirectoryNotFound => 'Verzeichnis nicht gefunden.';

  @override
  String get mainPathCopied => 'Pfad in die Zwischenablage kopiert';

  @override
  String get mainRevealInFileManager => 'Im Dateimanager anzeigen';

  @override
  String get mainRefresh => 'Erneuern';

  @override
  String get mainNoConfigFiles => 'Keine Konfigurationsdateien gefunden';

  @override
  String get batchTitle => 'Batch Commands';

  @override
  String get batchAddCommand => 'Batch Command hinzufügen';

  @override
  String get batchFieldTitle => 'Titel *';

  @override
  String get batchFieldCommand => 'Befehl *';

  @override
  String get batchUntitled => 'Ohne Titel';

  @override
  String get batchNoCommands => 'Keine Befehle gefunden.';

  @override
  String get batchDeleteTitle => 'Batch Command löschen?';

  @override
  String batchDeleteMessage(String title) {
    return 'Soll „$title“ dauerhaft gelöscht werden?';
  }

  @override
  String batchSaveFailed(String error) {
    return 'Befehl konnte nicht gespeichert werden: $error';
  }

  @override
  String batchDeleteFailed(String error) {
    return 'Befehl konnte nicht gelöscht werden: $error';
  }

  @override
  String batchInsertFailed(String error) {
    return 'Fehler beim Einfügen: $error';
  }

  @override
  String get batchInsertIntoTerminal => 'Ins interne Terminal einfügen';

  @override
  String get batchCopyCommand => 'Befehl kopieren';

  @override
  String get batchCommandCopied => 'Befehl in die Zwischenablage kopiert';

  @override
  String get batchDeleteCommand => 'Batch Command löschen';

  @override
  String get commonName => 'Name';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonOpen => 'Öffnen';

  @override
  String get commonCopy => 'Kopieren';

  @override
  String get commonPaste => 'Einfügen';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String railClose(String tool) {
    return '$tool schließen';
  }

  @override
  String terminalCommandHint(String profile) {
    return 'Befehle für $profile ...';
  }

  @override
  String get terminalSendToTerminal => 'An Terminal senden';

  @override
  String get terminalSearch => 'Terminal durchsuchen';

  @override
  String get terminalCloseSearch => 'Suche schließen';

  @override
  String get terminalMoreActions => 'Weitere Terminal-Aktionen';

  @override
  String get terminalRestartSession => 'Sitzung neu starten';

  @override
  String get terminalCloseTabHint =>
      'Tab schließen · Rechtsklick für Tab-Aktionen';

  @override
  String get terminalNewTab => 'Neuer Terminal-Tab';

  @override
  String get terminalOpenSavedTab => 'Gespeicherten Terminal-Tab öffnen';

  @override
  String get terminalNoSavedTabs => 'Keine gespeicherten Tabs';

  @override
  String get terminalSaveTabTitle => 'Terminal-Tab speichern';

  @override
  String get terminalUpdateSavedTab => 'Gespeicherten Tab aktualisieren';

  @override
  String get terminalSaveTabNote =>
      'Pro Pane werden bis zu 20 Command-Block-Befehle gespeichert. Befehle können sensible Werte enthalten; Terminalausgaben werden nicht gespeichert.';

  @override
  String terminalTabSaved(String name) {
    return 'Terminal-Tab „$name“ wurde gespeichert.';
  }

  @override
  String terminalSaveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String terminalOpenSnapshotTitle(String name) {
    return '„$name“ öffnen';
  }

  @override
  String terminalSnapshotSummary(int panes, int commands) {
    return '$panes Terminal-Panes · $commands gespeicherte Befehle';
  }

  @override
  String get terminalDeleteSavedTab => 'Gespeicherten Zustand löschen';

  @override
  String get terminalDeleteSavedTabTitle => 'Gespeicherten Zustand löschen?';

  @override
  String terminalDeleteSavedTabMessage(Object name) {
    return 'Möchtest du „$name“ wirklich löschen? Bereits geöffnete Terminalsitzungen bleiben unverändert.';
  }

  @override
  String get terminalRunSavedCommands =>
      'Gespeicherte Befehle nach dem Öffnen direkt ausführen';

  @override
  String get terminalRunSavedCommandsNote =>
      'Die Befehle laufen je Pane nacheinander.';

  @override
  String terminalOpenFailed(String error) {
    return 'Öffnen fehlgeschlagen: $error';
  }

  @override
  String terminalAutoRunFailed(String error) {
    return 'Automatische Ausführung fehlgeschlagen: $error';
  }

  @override
  String get terminalRestartTitle => 'Terminal-Sitzung neu starten?';

  @override
  String get terminalRestartMessage =>
      'Der laufende Prozess wird kontrolliert beendet und die Sitzung direkt neu gestartet. Die bisherige Terminalausgabe wird zurückgesetzt; nicht gesendete Befehle bleiben erhalten.';

  @override
  String get terminalRestart => 'Neu starten';

  @override
  String terminalRestartFailed(String error) {
    return 'Sitzung konnte nicht neu gestartet werden: $error';
  }

  @override
  String get terminalRenameTab => 'Tab umbenennen';

  @override
  String get terminalSaveTab => 'Tab speichern';

  @override
  String get terminalRenameTabTitle => 'Terminal-Tab umbenennen';

  @override
  String get terminalFieldTabName => 'Tabname';

  @override
  String get terminalRename => 'Umbenennen';

  @override
  String get terminalCloseTabTitle => 'Terminal-Tab schließen?';

  @override
  String get terminalCloseTabMessage =>
      'Alle laufenden Sitzungen dieses Tabs werden beendet.';

  @override
  String get terminalCloseTab => 'Tab schließen';

  @override
  String terminalCloseTabFailed(String error) {
    return 'Tab konnte nicht geschlossen werden: $error';
  }

  @override
  String get terminalTrueColorTooltip => 'xterm-256color mit 24-Bit-True-Color';

  @override
  String get terminalAlternateScreenActive => 'Alternate Screen aktiv';

  @override
  String get terminalMouseControlActive => 'Terminal-Maussteuerung aktiv';

  @override
  String terminalCommandBlocksCount(int count) {
    return 'Command Blocks ($count)';
  }

  @override
  String get terminalSplitLeftRight => 'Fenster links/rechts teilen';

  @override
  String get terminalSplitTopBottom => 'Fenster oben/unten teilen';

  @override
  String get terminalClosePane => 'Fenster schließen';

  @override
  String get terminalCloseRunningPaneTitle => 'Laufendes Terminal schließen?';

  @override
  String get terminalCloseRunningPaneMessage =>
      'Die laufende Sitzung wird beendet.';

  @override
  String get terminalCancel => 'Abbrechen';

  @override
  String get terminalRestoreSplitView => 'Geteilte Ansicht wiederherstellen';

  @override
  String get terminalMaximizePane => 'Terminal-Pane maximieren';

  @override
  String get terminalDecreaseFontSize => 'Verkleinern';

  @override
  String get terminalIncreaseFontSize => 'Vergrößern';

  @override
  String get terminalJumpToOutput => 'Zum aktuellen Output';

  @override
  String get terminalNoMatches => '0 Treffer';

  @override
  String get terminalSearchScrollback => 'Scrollback durchsuchen';

  @override
  String get terminalPreviousMatch => 'Vorheriger Treffer';

  @override
  String get terminalNextMatch => 'Nächster Treffer';

  @override
  String get terminalCommandBlocks => 'Command Blocks';

  @override
  String get terminalNotWhileRunning => 'Während eines Befehls nicht möglich';

  @override
  String get terminalClearCommandBlocks => 'Command Blocks leeren';

  @override
  String get terminalNoCommandsYet =>
      'Noch keine Befehle über Terminal Master gesendet.';

  @override
  String get terminalSavedCommands => 'Gespeicherte Befehle';

  @override
  String get terminalFilterAll => 'Alle';

  @override
  String get terminalFilterCurrentSession => 'Aktuelle Sitzung';

  @override
  String get terminalRunNow => 'Direkt ausführen';

  @override
  String get terminalMoreActionsShort => 'Weitere Aktionen';

  @override
  String terminalRunFailed(String error) {
    return 'Ausführen fehlgeschlagen: $error';
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

    return 'Ausgabe wurde nach $limitString Zeichen gekürzt.';
  }

  @override
  String get terminalLabelCommand => 'Befehl';

  @override
  String get terminalLabelOutput => 'Ausgabe';

  @override
  String get terminalExport => 'Export';

  @override
  String get terminalExportCommandBlock => 'Command Block exportieren';

  @override
  String terminalExportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get terminalStatusRunningBlock => 'Läuft';

  @override
  String get terminalStatusSucceeded => 'Erfolgreich (Exit 0)';

  @override
  String terminalStatusFailed(String exitCode) {
    return 'Fehlgeschlagen (Exit $exitCode)';
  }

  @override
  String get terminalStatusInterrupted => 'Unterbrochen';

  @override
  String get terminalOpenLink => 'Link öffnen';

  @override
  String get terminalSelectAll => 'Alles auswählen';

  @override
  String get terminalSearchSelection => 'Auswahl suchen';

  @override
  String get terminalClearOutput => 'Ausgabe leeren';

  @override
  String terminalOpenLinkFailed(String error) {
    return 'Link konnte nicht geöffnet werden: $error';
  }

  @override
  String get terminalPasteMultilineTitle => 'Mehrzeiligen Text einfügen?';

  @override
  String get terminalPasteMultilineMessage =>
      'Zeilenumbrüche können Befehle unmittelbar ausführen. Prüfe den Inhalt vor dem Einfügen.';

  @override
  String get terminalStatusReady => 'Bereit';

  @override
  String get terminalStatusStarting => 'Terminal wird gestartet ...';

  @override
  String get terminalStatusActive => 'Terminal läuft';

  @override
  String terminalStatusExited(String exitCode) {
    return 'Prozess beendet ($exitCode)';
  }

  @override
  String get terminalExitCodeUnknown => 'unbekannt';

  @override
  String terminalStatusStartFailed(String error) {
    return 'Terminal konnte nicht gestartet werden: $error';
  }

  @override
  String terminalInfoShell(String name) {
    return 'Shell: $name';
  }

  @override
  String terminalInfoDirectory(String directory) {
    return 'Verzeichnis: $directory';
  }

  @override
  String terminalInfoStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get hostKeyUnknownTitle => 'Unbekannter SSH-Server';

  @override
  String hostKeyUnknownMessage(
    String endpoint,
    String keyType,
    String fingerprint,
  ) {
    return 'Für $endpoint ist noch kein Host-Key gespeichert.\n\nTyp: $keyType\nFingerprint: $fingerprint\n\nVergleiche den Fingerprint mit einer vertrauenswürdigen Quelle.';
  }

  @override
  String get hostKeyTrustOnce => 'Einmal vertrauen';

  @override
  String get hostKeyTrustPermanently => 'Dauerhaft vertrauen';

  @override
  String get hostKeyChangedTitle => 'SSH-Host-Key geändert';

  @override
  String hostKeyChangedMessage(
    String endpoint,
    String stored,
    String received,
  ) {
    return 'Die Identität von $endpoint stimmt nicht mit dem gespeicherten Host-Key überein. Die Verbindung wurde blockiert.\n\nGespeichert: $stored\nEmpfangen: $received';
  }

  @override
  String get sshPageTitle => 'SSH-Verbindungen';

  @override
  String get sshNoProfilesYet => 'Noch keine SSH-Verbindungen gespeichert.';

  @override
  String get sshNoProfilesFound => 'Keine SSH-Verbindungen gefunden.';

  @override
  String get sshSearchHint => 'SSH-Verbindungen durchsuchen';

  @override
  String get sshClearSearch => 'Suche löschen';

  @override
  String get sshAddConnection => 'Verbindung hinzufügen';

  @override
  String get sshTest => 'Testen';

  @override
  String get sshEdit => 'Bearbeiten';

  @override
  String get sshConnect => 'Verbinden';

  @override
  String get sshSave => 'Speichern';

  @override
  String get sshAuthenticationKeyLabel => 'Authentifizierung: SSH-Key';

  @override
  String get sshAuthenticationPasswordLabel => 'Authentifizierung: Passwort';

  @override
  String get sshHostKeyConfirmed => 'Host-Key bestätigt';

  @override
  String get sshHostKeyUnconfirmed => 'Host-Key nicht bestätigt';

  @override
  String get sshProfileChangedReopen =>
      'Das SSH-Profil wurde zwischenzeitlich geändert. Öffne es erneut.';

  @override
  String get sshProfileChangedDeleteAgain =>
      'Das SSH-Profil wurde zwischenzeitlich geändert. Lösche es erneut.';

  @override
  String get sshProfilesChangedRetry =>
      'Die SSH-Profile wurden zwischenzeitlich geändert. Versuche es erneut.';

  @override
  String get sshPasswordRequired => 'Bitte gib ein SSH-Passwort ein.';

  @override
  String sshSavedButCredentialCleanupFailed(String error) {
    return 'Das Profil wurde gespeichert, aber die vorherigen Anmeldedaten konnten nicht aus dem Schlüsselbund entfernt werden: $error';
  }

  @override
  String sshSaveFailedWithCleanup(String error, String cleanupError) {
    return 'SSH-Profil konnte nicht gespeichert werden: $error\nZusätzlich konnten temporäre Anmeldedaten nicht entfernt werden: $cleanupError';
  }

  @override
  String sshSaveFailed(String error) {
    return 'SSH-Profil konnte nicht gespeichert werden: $error';
  }

  @override
  String get sshDeleteTitle => 'SSH-Verbindung löschen?';

  @override
  String sshDeleteMessage(String name) {
    return 'Soll „$name“ einschließlich der gespeicherten Anmeldedaten gelöscht werden?';
  }

  @override
  String sshDeletedButCredentialCleanupFailed(String error) {
    return 'Das Profil wurde gelöscht, aber die Anmeldedaten konnten nicht aus dem Schlüsselbund entfernt werden: $error';
  }

  @override
  String sshDeleteFailed(String error) {
    return 'SSH-Profil konnte nicht gelöscht werden: $error';
  }

  @override
  String get sshConnectionSucceeded => 'SSH-Verbindung erfolgreich.';

  @override
  String sshConnectionFailed(String error) {
    return 'SSH-Verbindung fehlgeschlagen: $error';
  }

  @override
  String get sshExportDialogTitle => 'Verschlüsseltes SSH-Backup exportieren';

  @override
  String get sshImportDialogTitle => 'Verschlüsseltes SSH-Backup importieren';

  @override
  String get sshImportBackupTooltip => 'Verschlüsseltes Backup importieren';

  @override
  String get sshExportBackupTooltip => 'Verschlüsseltes Backup exportieren';

  @override
  String sshExportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SSH-Verbindungen verschlüsselt exportiert.',
      one: '1 SSH-Verbindung verschlüsselt exportiert.',
    );
    return '$_temp0';
  }

  @override
  String sshExportFailed(String error) {
    return 'SSH-Export fehlgeschlagen: $error';
  }

  @override
  String sshBackupFilePickFailed(String error) {
    return 'Backup-Datei konnte nicht gewählt werden: $error';
  }

  @override
  String sshImportSummary(int imported, int replaced, int skipped) {
    return '$imported importiert, $replaced ersetzt, $skipped übersprungen.';
  }

  @override
  String sshImportFailed(String error) {
    return 'SSH-Import fehlgeschlagen: $error';
  }

  @override
  String get sshBackupFileTooLarge => 'Die Backup-Datei ist zu groß.';

  @override
  String get sshBackupDialogTitle => 'Verschlüsseltes SSH-Backup';

  @override
  String get sshBackupExportExplanation =>
      'Das Backup enthält die ausgewählten Verbindungen und deren Passwörter beziehungsweise Key-Passphrases. Private Schlüsseldateien werden nicht eingebettet. Das Backup wird mit Argon2id und AES-256-GCM geschützt.';

  @override
  String get sshBackupPasswordLabel => 'Backup-Passwort';

  @override
  String get sshBackupPasswordHelper => 'Mindestens 12 Zeichen';

  @override
  String get sshBackupPasswordTooShort => 'Mindestens 12 Zeichen erforderlich.';

  @override
  String get sshBackupPasswordRepeatLabel => 'Backup-Passwort wiederholen';

  @override
  String get sshBackupPasswordMismatch =>
      'Die Passwörter stimmen nicht überein.';

  @override
  String get sshBackupPasswordNeeded => 'Backup-Passwort erforderlich.';

  @override
  String get sshBackupDecryptTitle => 'SSH-Backup entschlüsseln';

  @override
  String get sshExport => 'Exportieren';

  @override
  String get sshDecrypt => 'Entschlüsseln';

  @override
  String get sshImport => 'Importieren';

  @override
  String get sshSelectAtLeastOne => 'Wähle mindestens eine Verbindung aus.';

  @override
  String get sshImportReviewTitle => 'SSH-Import prüfen';

  @override
  String get sshKeyShort => 'SSH-Key';

  @override
  String get sshPasswordShort => 'Passwort';

  @override
  String get sshImportDuplicateEndpoint => 'Doppelter Endpunkt im Backup';

  @override
  String get sshImportExistingFound => 'Vorhandene Verbindung gefunden';

  @override
  String get sshImportNewConnection => 'Neue Verbindung';

  @override
  String get sshImportHostKeyWarning => 'Warnung: Host-Key unterscheidet sich';

  @override
  String get sshImportSkip => 'Überspringen';

  @override
  String get sshImportReplace => 'Ersetzen';

  @override
  String get sshImportNew => 'Neu';

  @override
  String get sshImportAsCopy => 'Als Kopie';

  @override
  String get sshEditTitle => 'SSH-Verbindung bearbeiten';

  @override
  String get sshAddTitle => 'SSH-Verbindung hinzufügen';

  @override
  String get sshFieldDisplayName => 'Anzeigename';

  @override
  String get sshFieldHost => 'Serveradresse';

  @override
  String get sshFieldPort => 'Port';

  @override
  String get sshFieldUsername => 'Benutzername';

  @override
  String get sshFieldAuthentication => 'Authentifizierung';

  @override
  String get sshPortRange => 'Port muss zwischen 1 und 65535 liegen.';

  @override
  String get sshAuthenticationKeyDesktop => 'SSH-Key (Desktop)';

  @override
  String get sshFieldPrivateKeyFile => 'Private Schlüsseldatei';

  @override
  String get sshPickKeyFile => 'Schlüsseldatei auswählen';

  @override
  String get sshPrivateKeyRequired => 'Wähle eine private Schlüsseldatei aus.';

  @override
  String get sshClearStoredPassphrase => 'Gespeicherte Passphrase entfernen';

  @override
  String get sshKeyPassphraseKeep =>
      'Key-Passphrase (leer lassen zum Beibehalten)';

  @override
  String get sshKeyPassphraseOptional => 'Key-Passphrase (optional)';

  @override
  String get sshPasswordKeep => 'Neues Passwort (leer lassen zum Beibehalten)';

  @override
  String get sshPasswordLabel => 'Passwort';

  @override
  String get sshShowPassword => 'Passwort anzeigen';

  @override
  String get sshHidePassword => 'Passwort ausblenden';

  @override
  String get sshPasswordNotEmpty => 'Passwort darf nicht leer sein.';

  @override
  String get sshCredentialStorageNote =>
      'Passwörter und Key-Passphrases werden ausschließlich im Schlüsselbund des Betriebssystems gespeichert. Private Schlüssel verbleiben in der ausgewählten Datei.';

  @override
  String sshFieldNotEmpty(String label) {
    return '$label darf nicht leer sein.';
  }

  @override
  String sshFieldInvalidControlCharacters(String label) {
    return '$label enthält ungültige Steuerzeichen.';
  }

  @override
  String get sshKeyFilesDesktopOnly =>
      'SSH-Key-Dateien werden derzeit nur auf Desktop-Plattformen unterstützt, da mobile Dateiauswahlen keine dauerhaft nutzbaren Pfade bereitstellen.';

  @override
  String get sshPickPrivateKeyDialogTitle =>
      'Private SSH-Schlüsseldatei auswählen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSectionTerminal => 'Terminal';

  @override
  String get settingsDefaultShellLabel => 'Standard-Shell';

  @override
  String get settingsDefaultShellHelper =>
      'Wird für neue Terminal-Tabs verwendet.';

  @override
  String get settingsDefaultShellSaved => 'Standard-Shell wurde gespeichert.';

  @override
  String settingsDefaultShellSaveFailed(String error) {
    return 'Standard-Shell konnte nicht gespeichert werden: $error';
  }

  @override
  String get settingsSectionCommandBuilder => 'Command Builder';

  @override
  String get settingsYamlDirectoryLabel => 'Standard-YAML-Ordner';

  @override
  String get settingsYamlDirectoryHelper =>
      'Vorlagen werden aus diesem Ordner geladen.';

  @override
  String get settingsSelectYamlDirectory => 'YAML-Ordner auswählen';

  @override
  String get settingsYamlDirectoryMissing =>
      'Der ausgewählte Ordner existiert nicht.';

  @override
  String get settingsYamlDirectorySaved =>
      'Standard-YAML-Ordner wurde gespeichert.';

  @override
  String settingsYamlDirectorySaveFailed(String error) {
    return 'Standard-YAML-Ordner konnte nicht gespeichert werden: $error';
  }

  @override
  String get settingsSectionLanguage => 'Sprache';

  @override
  String get settingsLanguageLabel => 'Sprache';

  @override
  String get settingsLanguageHelper => 'Wird sofort übernommen.';

  @override
  String get settingsLanguageSystem => 'Systemsprache';

  @override
  String get settingsLanguageSaved => 'Sprache wurde gespeichert.';

  @override
  String settingsLanguageSaveFailed(String error) {
    return 'Sprache konnte nicht gespeichert werden: $error';
  }
}
