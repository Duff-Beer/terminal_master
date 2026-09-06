import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../models/shell_profile.dart';
import '../models/saved_terminal_tab.dart';
import '../models/ssh_connection_profile.dart';
import '../models/terminal_command_block.dart';
import '../services/command_risk_assessor.dart';
import '../services/terminal_backend.dart';
import '../services/external_url_launcher.dart';
import '../services/saved_terminal_tab_store.dart';
import '../services/terminal_session.dart';
import '../theme.dart';
import 'command_confirmation_dialog.dart';
import 'terminal_mouse_overlay.dart';

enum TerminalSplitOrientation { vertical, horizontal }

class TerminalPaneData {
  final String id;
  final ShellProfile profile;
  final int row;
  final int column;
  final TextEditingController commandController = TextEditingController();
  final List<SavedTerminalCommand> savedCommands;
  TerminalSession session;
  bool isSearchOpen = false;

  TerminalPaneData({
    required this.id,
    required this.profile,
    required this.row,
    required this.column,
    required this.session,
    List<SavedTerminalCommand> savedCommands = const [],
  }) : savedCommands = List.of(savedCommands);

  void dispose() {
    commandController.dispose();
    session.dispose();
  }
}

class TerminalTab {
  final String id;
  final List<TerminalPaneData> panes;
  late String focusedPaneId;
  bool isVerticallySplit = false;
  bool isHorizontallySplit = false;
  String? maximizedPaneId;
  String? customName;
  String? snapshotId;
  String? snapshotName;
  DateTime? snapshotUpdatedAt;

  TerminalTab({required this.id, required TerminalPaneData pane})
    : panes = [pane],
      focusedPaneId = pane.id;

  TerminalPaneData get primaryPane => panes.first;
  List<TerminalPaneData> get visiblePanes => panes
      .where(
        (pane) =>
            (pane.column == 0 || isVerticallySplit) &&
            (pane.row == 0 || isHorizontallySplit),
      )
      .toList(growable: false);
  List<TerminalPaneData> get displayedPanes {
    final maximizedId = maximizedPaneId;
    if (maximizedId == null) return visiblePanes;
    return visiblePanes
        .where((pane) => pane.id == maximizedId)
        .toList(growable: false);
  }

  TerminalPaneData get activePane => panes.firstWhere(
    (pane) => pane.id == focusedPaneId,
    orElse: () => primaryPane,
  );

  String get displayName =>
      customName ??
      snapshotName ??
      activePane.session.title ??
      activePane.profile.name;

  bool hasSplit(TerminalSplitOrientation orientation) => switch (orientation) {
    TerminalSplitOrientation.vertical => isVerticallySplit,
    TerminalSplitOrientation.horizontal => isHorizontallySplit,
  };

  TerminalPaneData? paneAt({required int row, required int column}) {
    for (final pane in panes) {
      if (pane.row == row && pane.column == column) return pane;
    }
    return null;
  }

  void dispose() {
    for (final pane in panes) {
      pane.dispose();
    }
  }
}

class TerminalPanelController extends ChangeNotifier {
  static const minFontSize = 9.0;
  static const maxFontSize = 24.0;
  static const defaultFontSize = 13.0;
  static const maxTabNameLength = 60;

  final TerminalBackendFactory backendFactory;
  final GlobalKey<NavigatorState> navigatorKey;
  final List<ShellProfile> profiles;
  final SavedTerminalTabStore savedTabStore;

  TerminalPanelController({
    required this.backendFactory,
    required this.navigatorKey,
    required this.savedTabStore,
    List<ShellProfile>? profiles,
  }) : profiles = List.unmodifiable(
         profiles == null || profiles.isEmpty
             ? ShellProfile.platformDefaults()
             : profiles,
       ) {
    _defaultProfileId = this.profiles.first.id;
    final tab = _newTab(this.profiles.first);
    _tabs.add(tab);
    _activeTabId = tab.id;
    _savedTabsLoad = _loadSavedTabs();
  }

  final List<TerminalTab> _tabs = [];
  final List<SavedTerminalTab> _savedTabs = [];
  late final Future<void> _savedTabsLoad;
  Future<void> _savedTabsMutation = Future.value();
  var _nextTabId = 1;
  var _nextPaneId = 1;
  late String _activeTabId;
  late String _defaultProfileId;
  bool _isAttached = false;
  bool _isLoadingSavedTabs = true;
  String? _savedTabsError;
  double _fontSize = defaultFontSize;
  bool _disposed = false;

  List<TerminalTab> get tabs => List.unmodifiable(_tabs);
  List<SavedTerminalTab> get savedTabs => List.unmodifiable(_savedTabs);
  TerminalTab get activeTab => _tab(_activeTabId);
  TerminalPaneData get activePane => activeTab.activePane;
  TerminalPaneData get primaryPane => activeTab.primaryPane;
  List<TerminalPaneData> get visiblePanes => activeTab.visiblePanes;
  TerminalSession get session => activePane.session;
  TextEditingController get commandController => activePane.commandController;
  ShellProfile get activeProfile => activePane.profile;
  ShellProfile get defaultProfile =>
      profiles.firstWhere((profile) => profile.id == _defaultProfileId);

  bool get isLoadingSavedTabs => _isLoadingSavedTabs;
  String? get savedTabsError => _savedTabsError;
  bool get isSearchOpen => activePane.isSearchOpen;
  bool get isSplit =>
      activeTab.isVerticallySplit || activeTab.isHorizontallySplit;
  String? get maximizedPaneId => activeTab.maximizedPaneId;
  bool hasSplit(TerminalSplitOrientation orientation) =>
      activeTab.hasSplit(orientation);
  bool isPaneMaximized(String paneId) => activeTab.maximizedPaneId == paneId;
  double get fontSize => _fontSize;

  Future<void> attach() async {
    if (_isAttached) return;
    _isAttached = true;
    await Future.wait(visiblePanes.map(_startForDisplay));
  }

  void toggleSearch([String? paneId]) {
    final pane = _pane(paneId ?? activePane.id);
    pane.isSearchOpen = !pane.isSearchOpen;
    notifyListeners();
  }

  void openSearch([String? paneId]) {
    final pane = _pane(paneId ?? activePane.id);
    if (pane.isSearchOpen) return;
    pane.isSearchOpen = true;
    notifyListeners();
  }

  void closeSearch([String? paneId]) {
    final pane = _pane(paneId ?? activePane.id);
    if (!pane.isSearchOpen) return;
    pane.isSearchOpen = false;
    notifyListeners();
  }

  Future<void> createTab(ShellProfile profile, {bool activate = true}) async {
    final tab = _newTab(profile);
    _tabs.add(tab);
    if (activate) {
      _activeTabId = tab.id;
    }
    notifyListeners();
    if (_isAttached && activate) await _startForDisplay(tab.primaryPane);
  }

  Future<void> createDefaultTab() => createTab(defaultProfile);

  void setDefaultProfile(String profileId) {
    if (_defaultProfileId == profileId) return;
    if (!profiles.any((profile) => profile.id == profileId)) {
      throw ArgumentError.value(profileId, 'profileId', 'Unbekanntes Profil');
    }
    _defaultProfileId = profileId;
    notifyListeners();
  }

  Future<void> createSshTab(SshConnectionProfile connection) {
    return createTab(
      ShellProfile(
        id: 'ssh:${connection.id}',
        name: connection.name,
        executable: 'ssh',
        dialect: ShellDialect.posix,
        sshConnectionProfileId: connection.id,
      ),
    );
  }

  Future<void> _loadSavedTabs() async {
    try {
      _savedTabs
        ..clear()
        ..addAll(await savedTabStore.load());
      _savedTabsError = null;
    } on Object catch (error) {
      _savedTabsError =
          'Gespeicherte Tabs konnten nicht geladen werden: $error';
    } finally {
      _isLoadingSavedTabs = false;
      notifyListeners();
    }
  }

  Future<SavedTerminalTab> saveActiveTab([String? name]) {
    final tab = activeTab;
    final effectiveName =
        name ??
        tab.customName ??
        tab.snapshotName ??
        tab.activePane.session.title ??
        tab.activePane.profile.name;
    return _mutateSavedTabs(() => _saveTab(tab, effectiveName));
  }

  Future<SavedTerminalTab> _saveTab(TerminalTab tab, String name) async {
    await _savedTabsLoad;
    if (_savedTabsError case final error?) throw StateError(error);
    if (tab.panes.any((pane) => pane.profile.isSsh)) {
      throw StateError(
        'SSH-Terminal-Tabs können aus Sicherheitsgründen nicht als '
        'Terminal-Snapshot gespeichert werden.',
      );
    }
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Der Name darf nicht leer sein.');
    }
    final now = DateTime.now().toUtc();
    final existingIndex = tab.snapshotId == null
        ? -1
        : _savedTabs.indexWhere((snapshot) => snapshot.id == tab.snapshotId);
    final existing = existingIndex < 0 ? null : _savedTabs[existingIndex];
    final openedVersion = tab.snapshotUpdatedAt;
    if (existing != null &&
        openedVersion != null &&
        !openedVersion.isAtSameMomentAs(existing.updatedAt)) {
      throw StateError(
        'Dieser gespeicherte Tab wurde zwischenzeitlich geändert. '
        'Öffne die aktuelle Version erneut.',
      );
    }
    final snapshot = SavedTerminalTab(
      id: existing?.id ?? 'saved-${now.microsecondsSinceEpoch}',
      name: normalizedName,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      verticalSplit: tab.isVerticallySplit,
      horizontalSplit: tab.isHorizontallySplit,
      focusedRow: tab.activePane.row,
      focusedColumn: tab.activePane.column,
      panes: tab.panes.map((pane) {
        SavedTerminalPane? existingPane;
        for (final candidate
            in existing?.panes ?? const <SavedTerminalPane>[]) {
          if (candidate.row == pane.row && candidate.column == pane.column) {
            existingPane = candidate;
            break;
          }
        }
        return _savedPane(pane, existingPane?.commands ?? const []);
      }).toList(),
    );
    final updated = List<SavedTerminalTab>.of(_savedTabs);
    if (existingIndex < 0) {
      updated.insert(0, snapshot);
    } else {
      updated[existingIndex] = snapshot;
      updated.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    }
    await savedTabStore.save(updated);
    _savedTabs
      ..clear()
      ..addAll(updated);
    tab.snapshotId = snapshot.id;
    tab.snapshotName = snapshot.name;
    tab.customName = snapshot.name;
    tab.snapshotUpdatedAt = snapshot.updatedAt;
    _savedTabsError = null;
    notifyListeners();
    return snapshot;
  }

  Future<TerminalTab> openSavedTab(String snapshotId) async {
    await _savedTabsLoad;
    if (_savedTabsError case final error?) throw StateError(error);
    final snapshot = _savedTabs.firstWhere((tab) => tab.id == snapshotId);
    final sortedPanes = List<SavedTerminalPane>.of(snapshot.panes)
      ..sort((left, right) {
        final row = left.row.compareTo(right.row);
        return row != 0 ? row : left.column.compareTo(right.column);
      });
    final primarySnapshot = sortedPanes.firstWhere(
      (pane) => pane.row == 0 && pane.column == 0,
    );
    final primaryPane = _paneFromSnapshot(primarySnapshot);
    final tab =
        TerminalTab(id: 'terminal-tab-${_nextTabId++}', pane: primaryPane)
          ..snapshotId = snapshot.id
          ..snapshotName = snapshot.name
          ..customName = snapshot.name
          ..snapshotUpdatedAt = snapshot.updatedAt
          ..isVerticallySplit = snapshot.verticalSplit
          ..isHorizontallySplit = snapshot.horizontalSplit;
    for (final paneSnapshot in sortedPanes) {
      if (identical(paneSnapshot, primarySnapshot)) continue;
      tab.panes.add(_paneFromSnapshot(paneSnapshot));
    }
    final focused = tab.paneAt(
      row: snapshot.focusedRow,
      column: snapshot.focusedColumn,
    );
    if (focused != null && tab.visiblePanes.contains(focused)) {
      tab.focusedPaneId = focused.id;
    }
    _tabs.add(tab);
    _activeTabId = tab.id;
    notifyListeners();
    await Future.wait(tab.visiblePanes.map(_startForDisplay));
    return tab;
  }

  Future<void> deleteSavedTab(String snapshotId) =>
      _mutateSavedTabs(() => _deleteSavedTab(snapshotId));

  Future<void> _deleteSavedTab(String snapshotId) async {
    await _savedTabsLoad;
    if (_savedTabsError case final error?) throw StateError(error);
    final updated = _savedTabs
        .where((snapshot) => snapshot.id != snapshotId)
        .toList();
    await savedTabStore.save(updated);
    _savedTabs
      ..clear()
      ..addAll(updated);
    notifyListeners();
  }

  Future<T> _mutateSavedTabs<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _savedTabsMutation = _savedTabsMutation.then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<void> selectTab(String tabId) async {
    if (!_tabs.any((tab) => tab.id == tabId)) return;
    _activeTabId = tabId;
    notifyListeners();
    if (_isAttached) {
      final tab = _tab(tabId);
      await Future.wait(tab.visiblePanes.map(_startForDisplay));
    }
  }

  void focusPane(String paneId) {
    final tab = activeTab;
    if (tab.focusedPaneId == paneId || !_isVisiblePane(tab, paneId)) return;
    tab.focusedPaneId = paneId;
    notifyListeners();
  }

  void renameTab(String tabId, String name) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty ||
        normalizedName.length > maxTabNameLength ||
        normalizedName.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
      throw ArgumentError.value(name, 'name', 'Ungültiger Terminal-Tabname.');
    }
    final tab = _tab(tabId);
    if (tab.customName == normalizedName) return;
    tab.customName = normalizedName;
    notifyListeners();
  }

  void togglePaneMaximized(String paneId) {
    final tab = activeTab;
    if (!isSplit || !tab.visiblePanes.any((pane) => pane.id == paneId)) return;
    tab.maximizedPaneId = tab.maximizedPaneId == paneId ? null : paneId;
    tab.focusedPaneId = paneId;
    notifyListeners();
  }

  Future<void> toggleSplit(TerminalSplitOrientation orientation) async {
    final tab = activeTab;
    final enable = !tab.hasSplit(orientation);
    switch (orientation) {
      case TerminalSplitOrientation.vertical:
        tab.isVerticallySplit = enable;
      case TerminalSplitOrientation.horizontal:
        tab.isHorizontallySplit = enable;
    }
    if (enable) {
      if (tab.isVerticallySplit) {
        _ensurePane(tab, row: 0, column: 1);
      }
      if (tab.isHorizontallySplit) {
        _ensurePane(tab, row: 1, column: 0);
      }
      if (tab.isVerticallySplit && tab.isHorizontallySplit) {
        _ensurePane(tab, row: 1, column: 1);
      }
    }
    if (!tab.visiblePanes.any((pane) => pane.id == tab.focusedPaneId)) {
      tab.focusedPaneId = tab.primaryPane.id;
    }
    final maximizedPaneId = tab.maximizedPaneId;
    if (!isSplit ||
        (maximizedPaneId != null &&
            !tab.visiblePanes.any((pane) => pane.id == maximizedPaneId))) {
      tab.maximizedPaneId = null;
    }
    notifyListeners();
    if (_isAttached) {
      await Future.wait(tab.visiblePanes.map(_startForDisplay));
    }
  }

  Future<void> closeTab(String tabId) async {
    if (_tabs.length == 1) return;
    final tab = _tab(tabId);
    await Future.wait(
      tab.panes
          .where((pane) => pane.session.isRunning)
          .map((pane) => pane.session.stop()),
    );
    if (!_tabs.contains(tab) || _tabs.length == 1) return;
    for (final pane in tab.panes) {
      pane.session.removeListener(_handleSessionUpdate);
    }
    _tabs.remove(tab);
    tab.dispose();
    if (_activeTabId == tabId) _activeTabId = _tabs.first.id;
    notifyListeners();
  }

  Future<void> restartPane(String paneId) async {
    final pane = _pane(paneId);
    if (pane.session.isRunning) await pane.session.stop();
    pane.session.removeListener(_handleSessionUpdate);
    pane.session.dispose();
    pane.session = _newSession(pane.profile);
    notifyListeners();
    if (_isAttached && _isVisiblePane(activeTab, paneId)) {
      await _startForDisplay(pane);
    }
  }

  void zoomIn() => _setFontSize(_fontSize + 1);

  void zoomOut() => _setFontSize(_fontSize - 1);

  void resetZoom() => _setFontSize(defaultFontSize);

  void _setFontSize(double value) {
    final fontSize = value.clamp(minFontSize, maxFontSize);
    if (_fontSize == fontSize) return;
    _fontSize = fontSize;
    notifyListeners();
  }

  Future<void> insertCommand(String command) async {
    final pane = activePane;
    final controller = pane.commandController;
    final current = controller.text;
    controller.text = current.isEmpty ? command : '$current\n$command';
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    notifyListeners();
    await _startForDisplay(pane);
  }

  Future<void> sendPending() async {
    final pane = activePane;
    final controller = pane.commandController;
    final command = controller.text;
    if (command.trim().isEmpty) return;
    final activeSession = await _ensureStarted(pane);
    controller.clear();
    try {
      activeSession.sendTrackedCommand(command);
    } on Object {
      controller.text = command;
      rethrow;
    }
  }

  Future<void> stageSavedCommand(String paneId, String command) async {
    final pane = _pane(paneId);
    activeTab.focusedPaneId = pane.id;
    pane.commandController
      ..text = command
      ..selection = TextSelection.collapsed(offset: command.length);
    notifyListeners();
    await _startForDisplay(pane);
  }

  Future<void> executeSavedCommand(String paneId, String command) async {
    final pane = _pane(paneId);
    final activeSession = await _ensureStarted(pane);
    activeSession.sendTrackedCommand(command);
  }

  Future<void> executeSavedCommands(
    String paneId,
    Iterable<String> commands,
  ) async {
    final pane = _pane(paneId);
    final activeSession = await _ensureStarted(pane);
    for (final command in commands) {
      if (activeSession.hasActiveCommand) {
        await _waitForTrackedCommand(activeSession);
      }
      activeSession.sendTrackedCommand(command);
      await _waitForTrackedCommand(activeSession);
      if (activeSession.status != TerminalSessionStatus.running) break;
    }
  }

  Future<void> executeSavedTabCommands(String tabId) async {
    final tab = _tab(tabId);
    await Future.wait(
      tab.visiblePanes
          .where((pane) => pane.savedCommands.isNotEmpty)
          .map(
            (pane) => executeSavedCommands(
              pane.id,
              pane.savedCommands.map((command) => command.command),
            ),
          ),
    );
  }

  Future<TerminalSession> _ensureStarted(TerminalPaneData pane) async {
    final activeSession = pane.session;
    if (activeSession.status == TerminalSessionStatus.idle) {
      await activeSession.start();
    }
    if (activeSession.status != TerminalSessionStatus.running) {
      throw StateError(
        activeSession.error ?? 'Das integrierte Terminal ist nicht verfügbar.',
      );
    }
    return activeSession;
  }

  Future<void> _startForDisplay(TerminalPaneData pane) async {
    try {
      await _ensureStarted(pane);
    } on Object {
      // Startup failures are rendered in the corresponding terminal pane.
    }
  }

  TerminalTab _newTab(ShellProfile profile) {
    return TerminalTab(
      id: 'terminal-tab-${_nextTabId++}',
      pane: _newPane(profile, row: 0, column: 0),
    );
  }

  void _ensurePane(TerminalTab tab, {required int row, required int column}) {
    if (tab.paneAt(row: row, column: column) != null) return;
    tab.panes.add(_newPane(tab.primaryPane.profile, row: row, column: column));
  }

  TerminalPaneData _newPane(
    ShellProfile profile, {
    required int row,
    required int column,
  }) {
    return TerminalPaneData(
      id: 'terminal-pane-${_nextPaneId++}',
      profile: profile,
      row: row,
      column: column,
      session: _newSession(profile),
    );
  }

  TerminalPaneData _paneFromSnapshot(SavedTerminalPane snapshot) {
    final matchingProfiles = profiles.where(
      (profile) => profile.id == snapshot.profileId,
    );
    if (matchingProfiles.isEmpty) {
      throw StateError(
        'Das Shell-Profil "${snapshot.profileId}" ist nicht verfügbar.',
      );
    }
    final baseProfile = matchingProfiles.first;
    final profile = ShellProfile(
      id: baseProfile.id,
      name: baseProfile.name,
      executable: baseProfile.executable,
      arguments: baseProfile.arguments,
      workingDirectory:
          snapshot.workingDirectory ?? baseProfile.workingDirectory,
      environment: baseProfile.environment,
      dialect: baseProfile.dialect,
      sshConnectionProfileId: baseProfile.sshConnectionProfileId,
    );
    final pane = TerminalPaneData(
      id: 'terminal-pane-${_nextPaneId++}',
      profile: profile,
      row: snapshot.row,
      column: snapshot.column,
      session: _newSession(profile),
      savedCommands: snapshot.commands,
    );
    pane.commandController.text = snapshot.draft;
    return pane;
  }

  SavedTerminalPane _savedPane(
    TerminalPaneData pane,
    List<SavedTerminalCommand> previousCommands,
  ) {
    final commandCandidates = <SavedTerminalCommand>[
      ...previousCommands,
      ...pane.savedCommands,
      ...pane.session.commandBlocks
          .where((block) => block.status != TerminalCommandBlockStatus.running)
          .map(
            (block) => SavedTerminalCommand(
              command: block.command,
              executedAt: block.startedAt,
              exitCode: block.exitCode,
            ),
          ),
    ];
    final uniqueCommands = <String, SavedTerminalCommand>{};
    for (final command in commandCandidates) {
      final key =
          '${command.executedAt.microsecondsSinceEpoch}\u0000'
          '${command.exitCode}\u0000${command.command}';
      uniqueCommands[key] = command;
    }
    final commands = uniqueCommands.values.toList()
      ..sort((left, right) => left.executedAt.compareTo(right.executedAt));
    final recentCommands = commands.length > 20
        ? commands.sublist(commands.length - 20)
        : commands;
    return SavedTerminalPane(
      row: pane.row,
      column: pane.column,
      profileId: pane.profile.id,
      workingDirectory: pane.session.restorableWorkingDirectory,
      draft: pane.commandController.text,
      commands: List.unmodifiable(recentCommands),
    );
  }

  Future<void> _waitForTrackedCommand(TerminalSession session) {
    if (!session.hasActiveCommand) return Future.value();
    final completer = Completer<void>();
    void listener() {
      if (!session.hasActiveCommand ||
          session.status != TerminalSessionStatus.running) {
        session.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    }

    session.addListener(listener);
    return completer.future;
  }

  TerminalSession _newSession(ShellProfile profile) {
    final session = TerminalSession(
      backendFactory: backendFactory,
      profile: profile,
    );
    session.addListener(_handleSessionUpdate);
    return session;
  }

  TerminalTab _tab(String id) => _tabs.firstWhere((tab) => tab.id == id);

  TerminalPaneData _pane(String id) =>
      _tabs.expand((tab) => tab.panes).firstWhere((pane) => pane.id == id);

  bool _isVisiblePane(TerminalTab tab, String id) =>
      tab.id == _activeTabId && tab.displayedPanes.any((pane) => pane.id == id);

  void _handleSessionUpdate() => notifyListeners();

  @override
  void dispose() {
    _disposed = true;
    for (final tab in _tabs) {
      for (final pane in tab.panes) {
        pane.session.removeListener(_handleSessionUpdate);
      }
      tab.dispose();
    }
    _tabs.clear();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}

class TerminalPanelScope extends InheritedNotifier<TerminalPanelController> {
  const TerminalPanelScope({
    super.key,
    required TerminalPanelController controller,
    required super.child,
  }) : super(notifier: controller);

  static TerminalPanelController of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'TerminalPanelScope fehlt im Widget-Baum.');
    return scope!;
  }

  static TerminalPanelController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TerminalPanelScope>()
        ?.notifier;
  }
}

enum WorkspaceTool { configurations, sshConnections, settings }

class ConfigurationPanelController extends ChangeNotifier {
  bool _isOpen = false;
  WorkspaceTool _activeTool = WorkspaceTool.configurations;

  bool get isOpen => _isOpen;
  WorkspaceTool get activeTool => _activeTool;

  void open([WorkspaceTool tool = WorkspaceTool.configurations]) {
    if (_isOpen && _activeTool == tool) return;
    _activeTool = tool;
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  void toggle([WorkspaceTool tool = WorkspaceTool.configurations]) {
    if (_isOpen && _activeTool == tool) {
      close();
    } else {
      open(tool);
    }
  }
}

class ConfigurationPanelScope
    extends InheritedNotifier<ConfigurationPanelController> {
  const ConfigurationPanelScope({
    super.key,
    required ConfigurationPanelController controller,
    required super.child,
  }) : super(notifier: controller);

  static ConfigurationPanelController of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'ConfigurationPanelScope fehlt im Widget-Baum.');
    return scope!;
  }

  static ConfigurationPanelController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ConfigurationPanelScope>()
        ?.notifier;
  }
}

class TerminalWorkspace extends StatefulWidget {
  final TerminalBackendFactory backendFactory;
  final GlobalKey<NavigatorState> navigatorKey;
  final List<ShellProfile>? profiles;
  final SavedTerminalTabStore? savedTabStore;
  final Widget? sshPanel;
  final Widget? settingsPanel;
  final Widget child;

  const TerminalWorkspace({
    super.key,
    required this.backendFactory,
    required this.navigatorKey,
    this.profiles,
    this.savedTabStore,
    this.sshPanel,
    this.settingsPanel,
    required this.child,
  });

  @override
  State<TerminalWorkspace> createState() => _TerminalWorkspaceState();
}

class _TerminalWorkspaceState extends State<TerminalWorkspace> {
  late final TerminalPanelController _controller;
  late final ConfigurationPanelController _configurationController;
  final _configurationFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TerminalPanelController(
      backendFactory: widget.backendFactory,
      navigatorKey: widget.navigatorKey,
      profiles: widget.profiles,
      savedTabStore: widget.savedTabStore ?? MemorySavedTerminalTabStore(),
    );
    _configurationController = ConfigurationPanelController()
      ..addListener(_handleConfigurationVisibility);
    unawaited(_controller.attach());
  }

  void _handleConfigurationVisibility() {
    if (!_configurationController.isOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _configurationController.isOpen) {
        _configurationFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _configurationController
      ..removeListener(_handleConfigurationVisibility)
      ..dispose();
    _configurationFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TerminalPanelScope(
      controller: _controller,
      child: ConfigurationPanelScope(
        controller: _configurationController,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyB, control: true):
                _configurationController.toggle,
            const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
                _configurationController.toggle,
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_configurationController.isOpen) {
                _configurationController.close();
              }
            },
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _controller,
              _configurationController,
            ]),
            builder: (context, child) => Row(
              children: [
                _ConfigurationToolRail(
                  controller: _configurationController,
                  hasSshPanel: widget.sshPanel != null,
                  hasSettingsPanel: widget.settingsPanel != null,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final drawerWidth = constraints.maxWidth < 640
                          ? constraints.maxWidth
                          : 420.0;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: SizedBox(
                              key: const Key('terminal-workspace'),
                              child: Material(
                                color: TerminalMasterColors.background,
                                child: TerminalPanel(controller: _controller),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: !_configurationController.isOpen,
                              child: GestureDetector(
                                key: const Key('configuration-panel-barrier'),
                                behavior: HitTestBehavior.opaque,
                                onTap: _configurationController.close,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 0,
                            width: drawerWidth,
                            child: ClipRect(
                              child: AnimatedSlide(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                offset: _configurationController.isOpen
                                    ? Offset.zero
                                    : const Offset(-1, 0),
                                child: IgnorePointer(
                                  ignoring: !_configurationController.isOpen,
                                  child: Focus(
                                    focusNode: _configurationFocusNode,
                                    child: Material(
                                      key: const Key('configuration-panel'),
                                      color: TerminalMasterColors.surface,
                                      elevation: 16,
                                      shadowColor: Colors.black87,
                                      child: IndexedStack(
                                        index: switch (_configurationController
                                            .activeTool) {
                                          WorkspaceTool.configurations => 0,
                                          WorkspaceTool.sshConnections => 1,
                                          WorkspaceTool.settings => 2,
                                        },
                                        children: [
                                          KeyedSubtree(
                                            key: const Key(
                                              'configuration-tool-content',
                                            ),
                                            child: widget.child,
                                          ),
                                          KeyedSubtree(
                                            key: const Key('ssh-tool-content'),
                                            child:
                                                widget.sshPanel ??
                                                const SizedBox.shrink(),
                                          ),
                                          KeyedSubtree(
                                            key: const Key(
                                              'settings-tool-content',
                                            ),
                                            child:
                                                widget.settingsPanel ??
                                                const SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigurationToolRail extends StatelessWidget {
  final ConfigurationPanelController controller;
  final bool hasSshPanel;
  final bool hasSettingsPanel;

  const _ConfigurationToolRail({
    required this.controller,
    required this.hasSshPanel,
    required this.hasSettingsPanel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('workspace-tool-rail'),
      width: 48,
      child: ColoredBox(
        color: TerminalMasterColors.surfaceRaised,
        child: Column(
          children: [
            _buildButton(
              key: const Key('configuration-panel-toggle'),
              tool: WorkspaceTool.configurations,
              icon: Icons.tune,
              tooltip: 'Command Builder',
            ),
            if (hasSshPanel)
              _buildButton(
                key: const Key('ssh-panel-toggle'),
                tool: WorkspaceTool.sshConnections,
                icon: Icons.dns_outlined,
                tooltip: 'SSH-Verbindungen',
              ),
            if (hasSettingsPanel) const Spacer(),
            if (hasSettingsPanel)
              _buildButton(
                key: const Key('settings-panel-toggle'),
                tool: WorkspaceTool.settings,
                icon: Icons.settings_outlined,
                tooltip: 'Einstellungen',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required Key key,
    required WorkspaceTool tool,
    required IconData icon,
    required String tooltip,
  }) {
    final isActive = controller.isOpen && controller.activeTool == tool;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          if (isActive)
            Positioned(
              left: 0,
              top: 8,
              bottom: 8,
              child: Container(
                key: ValueKey('workspace-tool-indicator-${tool.name}'),
                width: 3,
                color: TerminalMasterColors.green,
              ),
            ),
          Positioned.fill(
            child: IconButton(
              key: key,
              tooltip: isActive ? '$tooltip schließen' : tooltip,
              onPressed: () => controller.toggle(tool),
              icon: Icon(
                icon,
                color: isActive ? TerminalMasterColors.green : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TerminalPanel extends StatelessWidget {
  final TerminalPanelController controller;

  const TerminalPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final pane = controller.activePane;
    return Column(
      children: [
        _buildTabBar(context),
        Expanded(child: _buildPanes()),
        Container(
          key: const Key('terminal-bottom-toolbar'),
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
          decoration: const BoxDecoration(
            color: TerminalMasterColors.surface,
            border: Border(top: BorderSide(color: TerminalMasterColors.border)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (constraints.maxWidth >= 560) ...[
                  _buildSearchButton(),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: TextField(
                    key: const Key('terminal-command-input'),
                    controller: controller.commandController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'Befehle für ${controller.activeProfile.name} ...',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  key: const Key('send-terminal-input'),
                  tooltip: 'An Terminal senden',
                  style: IconButton.styleFrom(
                    backgroundColor: TerminalMasterColors.green,
                    foregroundColor: TerminalMasterColors.background,
                  ),
                  onPressed: controller.sendPending,
                  icon: const Icon(Icons.send_rounded),
                ),
                if (constraints.maxWidth < 560) ...[
                  const SizedBox(width: 6),
                  _buildCompactActions(context, pane),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchButton() {
    return IconButton(
      key: const Key('terminal-search-toggle'),
      tooltip: controller.isSearchOpen
          ? 'Suche schließen'
          : 'Terminal durchsuchen',
      onPressed: controller.toggleSearch,
      icon: Icon(controller.isSearchOpen ? Icons.search_off : Icons.search),
    );
  }

  Widget _buildCompactActions(BuildContext context, TerminalPaneData pane) {
    return PopupMenuButton<String>(
      key: const Key('terminal-more-actions'),
      tooltip: 'Weitere Terminal-Aktionen',
      onSelected: (action) {
        switch (action) {
          case 'search':
            controller.toggleSearch();
          case 'restart':
            _confirmRestart(context, pane);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'search',
          child: ListTile(
            leading: Icon(
              controller.isSearchOpen ? Icons.search_off : Icons.search,
            ),
            title: Text(
              controller.isSearchOpen
                  ? 'Suche schließen'
                  : 'Terminal durchsuchen',
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'restart',
          child: ListTile(
            leading: Icon(Icons.restart_alt),
            title: Text('Sitzung neu starten'),
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      key: const Key('terminal-tab-bar'),
      height: 40,
      decoration: const BoxDecoration(
        color: TerminalMasterColors.surface,
        border: Border(bottom: BorderSide(color: TerminalMasterColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...controller.tabs.map((tab) {
                  final selected = controller.activeTab.id == tab.id;
                  final pane = tab.activePane;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                    child: Material(
                      color: selected
                          ? TerminalMasterColors.surfaceRaised
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      child: InkWell(
                        key: Key('terminal-tab-${tab.id}'),
                        onTap: () => controller.selectTab(tab.id),
                        onSecondaryTapDown: (details) => _showTabContextMenu(
                          context,
                          tab,
                          details.globalPosition,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _tabStatusIcon(pane.session.status),
                                size: 11,
                                color: _tabStatusColor(pane.session.status),
                              ),
                              const SizedBox(width: 5),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 120,
                                ),
                                child: Tooltip(
                                  message: tab.displayName,
                                  child: Text(
                                    tab.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? TerminalMasterColors.yellow
                                          : TerminalMasterColors.foreground,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    'Tab schließen · Rechtsklick für Tab-Aktionen',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 28,
                                  height: 28,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: controller.tabs.length == 1
                                    ? null
                                    : () => _confirmClose(context, tab),
                                icon: const Icon(Icons.close, size: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                IconButton(
                  key: const Key('new-terminal-tab'),
                  tooltip: 'Neuer Terminal-Tab',
                  icon: const Icon(Icons.add, size: 19),
                  onPressed: controller.createDefaultTab,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            key: const Key('open-saved-terminal-tab'),
            tooltip: 'Gespeicherten Terminal-Tab öffnen',
            enabled: !controller.isLoadingSavedTabs,
            icon: Icon(
              Icons.folder_open_outlined,
              size: 19,
              color: controller.savedTabsError == null
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
            onSelected: (id) => _openSavedTab(context, id),
            itemBuilder: (context) {
              if (controller.savedTabsError case final error?) {
                return [
                  PopupMenuItem<String>(enabled: false, child: Text(error)),
                ];
              }
              if (controller.savedTabs.isEmpty) {
                return const [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Text('Keine gespeicherten Tabs'),
                  ),
                ];
              }
              return controller.savedTabs
                  .map(
                    (snapshot) => PopupMenuItem<String>(
                      value: snapshot.id,
                      child: Text(snapshot.name),
                    ),
                  )
                  .toList();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPanes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final activeTabId = controller.activeTab.id;
        final isVerticallySplit = controller.hasSplit(
          TerminalSplitOrientation.vertical,
        );
        final isHorizontallySplit = controller.hasSplit(
          TerminalSplitOrientation.horizontal,
        );
        final isPaneMaximized = controller.maximizedPaneId != null;
        final verticalOffset = constraints.maxWidth / 2;
        final horizontalOffset = constraints.maxHeight / 2;
        return Stack(
          children: [
            for (final tab in controller.tabs)
              for (final pane in tab.panes)
                Positioned(
                  key: Key('terminal-pane-position-${pane.id}'),
                  top: !isPaneMaximized && pane.row == 1 && isHorizontallySplit
                      ? horizontalOffset + 3
                      : 0,
                  bottom:
                      !isPaneMaximized && pane.row == 0 && isHorizontallySplit
                      ? horizontalOffset + 3
                      : 0,
                  left:
                      !isPaneMaximized && pane.column == 1 && isVerticallySplit
                      ? verticalOffset + 3
                      : 0,
                  right:
                      !isPaneMaximized && pane.column == 0 && isVerticallySplit
                      ? verticalOffset + 3
                      : 0,
                  child: Offstage(
                    offstage:
                        tab.id != activeTabId ||
                        !tab.displayedPanes.contains(pane),
                    child: IgnorePointer(
                      ignoring:
                          tab.id != activeTabId ||
                          !tab.displayedPanes.contains(pane),
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (_) => controller.focusPane(pane.id),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: controller.activePane.id == pane.id
                                  ? TerminalMasterColors.green
                                  : Colors.transparent,
                            ),
                          ),
                          child: TerminalPane(
                            key: ValueKey(pane.session),
                            pane: pane,
                            panelController: controller,
                            navigatorKey: controller.navigatorKey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            if (isHorizontallySplit && !isPaneMaximized)
              Positioned(
                left: 0,
                right: 0,
                top: horizontalOffset,
                height: 6,
                child: Container(color: TerminalMasterColors.border),
              ),
            if (isVerticallySplit && !isPaneMaximized)
              Positioned(
                top: 0,
                bottom: 0,
                left: verticalOffset,
                width: 6,
                child: Container(color: TerminalMasterColors.border),
              ),
          ],
        );
      },
    );
  }

  Future<void> _saveTab(BuildContext context) async {
    var enteredName =
        controller.activeTab.customName ??
        controller.activeTab.snapshotName ??
        controller.activePane.session.title ??
        controller.activeProfile.name;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          controller.activeTab.snapshotId == null
              ? 'Terminal-Tab speichern'
              : 'Gespeicherten Tab aktualisieren',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              key: const Key('saved-terminal-tab-name'),
              initialValue: enteredName,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (value) => enteredName = value,
              onFieldSubmitted: (value) {
                if (value.trim().isNotEmpty) Navigator.pop(context, value);
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Pro Pane werden bis zu 20 Command-Block-Befehle gespeichert. '
              'Befehle können sensible Werte enthalten; Terminalausgaben '
              'werden nicht gespeichert.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const Key('confirm-save-terminal-tab'),
            onPressed: () {
              final value = enteredName.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) return;
    try {
      await controller.saveActiveTab(name);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terminal-Tab „$name“ wurde gespeichert.')),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $error')),
      );
    }
  }

  Future<void> _openSavedTab(BuildContext context, String snapshotId) async {
    final snapshot = controller.savedTabs.firstWhere(
      (snapshot) => snapshot.id == snapshotId,
    );
    final commands = snapshot.panes
        .expand((pane) => pane.commands)
        .map((command) => command.command)
        .toList();
    var executeCommands = false;
    final dialogContext = controller.navigatorKey.currentContext ?? context;
    final openWithCommands = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('„${snapshot.name}“ öffnen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${snapshot.panes.length} Terminal-Panes · '
                '${commands.length} gespeicherte Befehle',
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                key: const Key('execute-saved-commands-on-open'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Gespeicherte Befehle nach dem Öffnen direkt ausführen',
                ),
                subtitle: const Text(
                  'Die Befehle laufen je Pane nacheinander.',
                ),
                value: executeCommands,
                onChanged: commands.isEmpty
                    ? null
                    : (value) => setDialogState(
                        () => executeCommands = value ?? false,
                      ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              key: const Key('confirm-open-saved-terminal-tab'),
              onPressed: () => Navigator.pop(context, executeCommands),
              child: const Text('Öffnen'),
            ),
          ],
        ),
      ),
    );
    if (openWithCommands == null || !context.mounted) return;
    if (openWithCommands) {
      final approved = await showCommandConfirmationDialog(
        dialogContext,
        commands: commands,
        assessment: CommandRiskAssessor.assessRawCommands(
          commands,
          containsRawConfiguration: false,
        ),
      );
      if (!approved || !context.mounted) return;
    }
    try {
      final tab = await controller.openSavedTab(snapshotId);
      if (!context.mounted) return;
      if (openWithCommands) {
        unawaited(_executeOpenedSavedTab(context, tab.id));
      }
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Öffnen fehlgeschlagen: $error')));
    }
  }

  Future<void> _executeOpenedSavedTab(
    BuildContext context,
    String tabId,
  ) async {
    try {
      await controller.executeSavedTabCommands(tabId);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Automatische Ausführung fehlgeschlagen: $error'),
        ),
      );
    }
  }

  Future<void> _confirmRestart(
    BuildContext context,
    TerminalPaneData pane, {
    TerminalTab? tab,
  }) async {
    var approved = true;
    if (pane.session.isRunning) {
      final dialogContext = controller.navigatorKey.currentContext;
      if (dialogContext == null) return;
      approved =
          await showDialog<bool>(
            context: dialogContext,
            builder: (context) => AlertDialog(
              title: const Text('Terminal-Sitzung neu starten?'),
              content: const Text(
                'Der laufende Prozess wird kontrolliert beendet und die '
                'Sitzung direkt neu gestartet. Die bisherige Terminalausgabe '
                'wird zurückgesetzt; nicht gesendete Befehle bleiben erhalten.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Neu starten'),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!approved || !context.mounted) return;
    try {
      if (tab != null) await controller.selectTab(tab.id);
      await controller.restartPane(pane.id);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sitzung konnte nicht neu gestartet werden: $error'),
        ),
      );
    }
  }

  Future<void> _showTabContextMenu(
    BuildContext context,
    TerminalTab tab,
    Offset position,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;
    final pane = tab.activePane;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Tab umbenennen'),
          ),
        ),
        PopupMenuItem(
          value: 'save',
          enabled: !tab.panes.any((pane) => pane.profile.isSsh),
          child: ListTile(
            leading: const Icon(Icons.bookmark_add_outlined),
            title: Text(
              tab.snapshotId == null
                  ? 'Tab speichern'
                  : 'Gespeicherten Tab aktualisieren',
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'restart',
          child: ListTile(
            leading: Icon(Icons.restart_alt),
            title: Text('Sitzung neu starten'),
          ),
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'rename':
        await _renameTab(context, tab);
      case 'save':
        await controller.selectTab(tab.id);
        if (context.mounted) await _saveTab(context);
      case 'restart':
        await _confirmRestart(context, pane, tab: tab);
    }
  }

  Future<void> _renameTab(BuildContext context, TerminalTab tab) async {
    final dialogContext = controller.navigatorKey.currentContext;
    if (dialogContext == null) return;
    var enteredName = tab.displayName;
    final name = await showDialog<String>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Terminal-Tab umbenennen'),
        content: TextFormField(
          key: const Key('terminal-tab-name'),
          initialValue: enteredName,
          autofocus: true,
          maxLength: TerminalPanelController.maxTabNameLength,
          decoration: const InputDecoration(labelText: 'Tabname'),
          onChanged: (value) => enteredName = value,
          onFieldSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const Key('confirm-rename-terminal-tab'),
            onPressed: () {
              final value = enteredName.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Umbenennen'),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) return;
    controller.renameTab(tab.id, name);
  }

  Future<void> _confirmClose(BuildContext context, TerminalTab tab) async {
    if (!tab.panes.any((pane) => pane.session.isRunning)) {
      await _closeTab(context, tab.id);
      return;
    }
    final dialogContext = controller.navigatorKey.currentContext;
    if (dialogContext == null) return;
    final approved =
        await showDialog<bool>(
          context: dialogContext,
          builder: (context) => AlertDialog(
            title: const Text('Terminal-Tab schließen?'),
            content: const Text(
              'Alle laufenden Sitzungen dieses Tabs werden beendet.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tab schließen'),
              ),
            ],
          ),
        ) ??
        false;
    if (approved && context.mounted) await _closeTab(context, tab.id);
  }

  Future<void> _closeTab(BuildContext context, String tabId) async {
    try {
      await controller.closeTab(tabId);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tab konnte nicht geschlossen werden: $error')),
      );
    }
  }

  IconData _tabStatusIcon(TerminalSessionStatus status) {
    return switch (status) {
      TerminalSessionStatus.idle => Icons.circle_outlined,
      TerminalSessionStatus.starting => Icons.pending,
      TerminalSessionStatus.running => Icons.circle,
      TerminalSessionStatus.exited => Icons.stop_circle_outlined,
      TerminalSessionStatus.failed => Icons.error_outline,
    };
  }

  Color _tabStatusColor(TerminalSessionStatus status) {
    return switch (status) {
      TerminalSessionStatus.idle => TerminalMasterColors.muted,
      TerminalSessionStatus.starting => TerminalMasterColors.yellow,
      TerminalSessionStatus.running => TerminalMasterColors.green,
      TerminalSessionStatus.exited => TerminalMasterColors.muted,
      TerminalSessionStatus.failed => TerminalMasterColors.red,
    };
  }
}

class TerminalPane extends StatefulWidget {
  final TerminalPaneData pane;
  final TerminalPanelController panelController;
  final GlobalKey<NavigatorState> navigatorKey;

  const TerminalPane({
    super.key,
    required this.pane,
    required this.panelController,
    required this.navigatorKey,
  });

  @override
  State<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends State<TerminalPane> {
  final _terminalController = TerminalController();
  final _terminalViewKey = GlobalKey<TerminalViewState>();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final List<TerminalHighlight> _searchHighlights = [];
  List<_TerminalSearchMatch> _searchMatches = [];
  int _activeSearchMatch = -1;
  bool _isAtBottom = true;
  bool _wasSearchOpen = false;
  bool _searchRefreshScheduled = false;
  bool _showCommandHistory = false;

  TerminalSession get session => widget.pane.session;

  static const _terminalTheme = TerminalTheme(
    cursor: TerminalMasterColors.green,
    selection: Color(0x663b82f6),
    foreground: TerminalMasterColors.green,
    background: TerminalMasterColors.background,
    black: TerminalMasterColors.background,
    red: Color(0xffff6b6b),
    green: TerminalMasterColors.green,
    yellow: TerminalMasterColors.yellow,
    blue: TerminalMasterColors.blue,
    magenta: Color(0xffc792ea),
    cyan: TerminalMasterColors.cyan,
    white: TerminalMasterColors.foreground,
    brightBlack: TerminalMasterColors.muted,
    brightRed: Color(0xffff8b8b),
    brightGreen: Color(0xff7ff6c9),
    brightYellow: Color(0xffffd978),
    brightBlue: Color(0xff8dbdff),
    brightMagenta: Color(0xffd9a8f1),
    brightCyan: Color(0xff8ce4f0),
    brightWhite: Color(0xffffffff),
    searchHitBackground: TerminalMasterColors.yellow,
    searchHitBackgroundCurrent: Color(0xffff8b3d),
    searchHitForeground: TerminalMasterColors.background,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    session.addListener(_handleSessionUpdate);
    session.terminal.addListener(_scheduleSearchRefresh);
  }

  @override
  void dispose() {
    session.removeListener(_handleSessionUpdate);
    session.terminal.removeListener(_scheduleSearchRefresh);
    _clearSearchHighlights();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _terminalController.dispose();
    super.dispose();
  }

  void _handleSessionUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isSearchOpen = widget.pane.isSearchOpen;
    if (isSearchOpen && !_wasSearchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
    _wasSearchOpen = isSearchOpen;

    return Column(
      children: [
        AnimatedBuilder(
          animation: session,
          builder: (context, child) => Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: TerminalMasterColors.surface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showSessionStatus = constraints.maxWidth >= 220;
                final showIndicators = constraints.maxWidth >= 360;
                final showZoomControls = constraints.maxWidth >= 480;
                final compactActionSize = constraints.maxWidth < 160
                    ? 28.0
                    : 32.0;
                return Row(
                  children: [
                    if (showSessionStatus) ...[
                      Icon(
                        _statusIcon(session.status),
                        size: 13,
                        color: _statusColor(session.status),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: _statusTooltip(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusTitle(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: session.title == null
                                      ? TerminalMasterColors.cyan
                                      : TerminalMasterColors.yellow,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                _sessionDetails(),
                                key: _paneKey('terminal-session-details'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: TerminalMasterColors.muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (showIndicators)
                      Tooltip(
                        message: 'xterm-256color mit 24-Bit-True-Color',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.palette_outlined,
                            key: _paneKey('terminal-true-color-indicator'),
                            size: 14,
                            color: TerminalMasterColors.cyan,
                          ),
                        ),
                      ),
                    if (showIndicators && session.terminal.isUsingAltBuffer)
                      Tooltip(
                        message: 'Alternate Screen aktiv',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.layers_outlined,
                            key: _paneKey('terminal-alt-screen-indicator'),
                            size: 14,
                            color: TerminalMasterColors.yellow,
                          ),
                        ),
                      ),
                    if (showIndicators &&
                        session.terminal.mouseMode != MouseMode.none)
                      Tooltip(
                        message: 'Terminal-Maussteuerung aktiv',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.mouse_outlined,
                            key: _paneKey('terminal-mouse-mode-indicator'),
                            size: 14,
                            color: TerminalMasterColors.green,
                          ),
                        ),
                      ),
                    _compactIconButton(
                      key: _paneKey('terminal-command-history-toggle'),
                      tooltip:
                          'Command Blocks (${session.commandBlocks.length})',
                      icon: _showCommandHistory
                          ? Icons.view_agenda
                          : Icons.view_agenda_outlined,
                      size: compactActionSize,
                      onPressed: () {
                        setState(
                          () => _showCommandHistory = !_showCommandHistory,
                        );
                      },
                    ),
                    _compactIconButton(
                      key: _paneKey('split-terminal-vertical'),
                      tooltip:
                          widget.panelController.hasSplit(
                            TerminalSplitOrientation.vertical,
                          )
                          ? 'Vertikale Teilung schließen'
                          : 'Terminal vertikal teilen',
                      icon: Icons.vertical_split_outlined,
                      size: compactActionSize,
                      color:
                          widget.panelController.hasSplit(
                            TerminalSplitOrientation.vertical,
                          )
                          ? TerminalMasterColors.yellow
                          : null,
                      onPressed: () => widget.panelController.toggleSplit(
                        TerminalSplitOrientation.vertical,
                      ),
                    ),
                    _compactIconButton(
                      key: _paneKey('split-terminal-horizontal'),
                      tooltip:
                          widget.panelController.hasSplit(
                            TerminalSplitOrientation.horizontal,
                          )
                          ? 'Horizontale Teilung schließen'
                          : 'Terminal horizontal teilen',
                      icon: Icons.horizontal_split_outlined,
                      size: compactActionSize,
                      color:
                          widget.panelController.hasSplit(
                            TerminalSplitOrientation.horizontal,
                          )
                          ? TerminalMasterColors.yellow
                          : null,
                      onPressed: () => widget.panelController.toggleSplit(
                        TerminalSplitOrientation.horizontal,
                      ),
                    ),
                    if (widget.panelController.isSplit)
                      _compactIconButton(
                        key: _paneKey('maximize-terminal-pane'),
                        tooltip:
                            widget.panelController.isPaneMaximized(
                              widget.pane.id,
                            )
                            ? 'Geteilte Ansicht wiederherstellen'
                            : 'Terminal-Pane maximieren',
                        icon:
                            widget.panelController.isPaneMaximized(
                              widget.pane.id,
                            )
                            ? Icons.close_fullscreen
                            : Icons.open_in_full,
                        color:
                            widget.panelController.isPaneMaximized(
                              widget.pane.id,
                            )
                            ? TerminalMasterColors.yellow
                            : null,
                        size: compactActionSize,
                        onPressed: () => widget.panelController
                            .togglePaneMaximized(widget.pane.id),
                      ),
                    if (showZoomControls) ...[
                      _compactIconButton(
                        key: _paneKey('terminal-zoom-out'),
                        tooltip: 'Verkleinern',
                        icon: Icons.remove,
                        onPressed: widget.panelController.zoomOut,
                      ),
                      TextButton(
                        key: _paneKey('terminal-zoom-reset'),
                        onPressed: widget.panelController.resetZoom,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(42, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: Text(
                          '${widget.panelController.fontSize.round()} px',
                        ),
                      ),
                      _compactIconButton(
                        key: _paneKey('terminal-zoom-in'),
                        tooltip: 'Vergrößern',
                        icon: Icons.add,
                        onPressed: widget.panelController.zoomIn,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        if (isSearchOpen) _buildSearchBar(),
        if (_showCommandHistory) _buildCommandHistory(),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: TerminalView(
                    session.terminal,
                    key: _terminalViewKey,
                    controller: _terminalController,
                    scrollController: _scrollController,
                    theme: _terminalTheme,
                    textStyle: TerminalStyle(
                      fontSize: widget.panelController.fontSize,
                    ),
                    padding: const EdgeInsets.all(10),
                    autofocus: false,
                    alwaysShowCursor: true,
                    onTapUp: _handleTerminalTap,
                    onSecondaryTapDown: _handleSecondaryTap,
                    onKeyEvent: _handleTerminalKey,
                  ),
                ),
              ),
              if (session.terminal.mouseMode != MouseMode.none)
                Positioned.fill(
                  child: TerminalMouseOverlay(
                    overlayKey: _paneKey('terminal-mouse-overlay'),
                    terminal: session.terminal,
                    terminalViewKey: _terminalViewKey,
                    scrollController: _scrollController,
                    sendInput: session.sendInput,
                  ),
                ),
              if (!_isAtBottom)
                Positioned(
                  right: 18,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    key: _paneKey('terminal-scroll-to-bottom'),
                    tooltip: 'Zum aktuellen Output',
                    onPressed: _scrollToBottom,
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compactIconButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
    double size = 32,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: size < 32 ? 16 : 18, color: color),
    );
  }

  Widget _buildSearchBar() {
    final resultText = _searchMatches.isEmpty
        ? '0 Treffer'
        : '${_activeSearchMatch + 1}/${_searchMatches.length}';
    return Container(
      key: _paneKey('terminal-search-bar'),
      color: TerminalMasterColors.surfaceRaised,
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: _paneKey('terminal-search-input'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                hintText: 'Scrollback durchsuchen',
                isDense: true,
              ),
              onChanged: (_) => _runSearch(),
              onSubmitted: (_) => _nextSearchMatch(),
            ),
          ),
          const SizedBox(width: 8),
          Text(resultText, style: const TextStyle(fontSize: 11)),
          _compactIconButton(
            key: _paneKey('terminal-search-previous'),
            tooltip: 'Vorheriger Treffer',
            icon: Icons.keyboard_arrow_up,
            onPressed: _previousSearchMatch,
          ),
          _compactIconButton(
            key: _paneKey('terminal-search-next'),
            tooltip: 'Nächster Treffer',
            icon: Icons.keyboard_arrow_down,
            onPressed: _nextSearchMatch,
          ),
          _compactIconButton(
            key: _paneKey('terminal-search-close'),
            tooltip: 'Suche schließen',
            icon: Icons.close,
            onPressed: () => widget.panelController.closeSearch(widget.pane.id),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandHistory() {
    final blocks = session.commandBlocks.reversed.toList();
    final savedCommands = widget.pane.savedCommands.reversed.toList();
    return Container(
      key: _paneKey('terminal-command-history'),
      height: 190,
      decoration: const BoxDecoration(
        color: TerminalMasterColors.surface,
        border: Border(bottom: BorderSide(color: TerminalMasterColors.border)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Command Blocks',
                    style: TextStyle(
                      color: TerminalMasterColors.yellow,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${blocks.length + savedCommands.length}',
                  style: const TextStyle(fontSize: 10),
                ),
                _compactIconButton(
                  key: _paneKey('clear-command-history'),
                  tooltip: session.hasActiveCommand
                      ? 'Während eines Befehls nicht möglich'
                      : 'Command Blocks leeren',
                  icon: Icons.delete_sweep_outlined,
                  onPressed: session.hasActiveCommand
                      ? null
                      : session.clearCommandBlocks,
                ),
              ],
            ),
          ),
          Expanded(
            child: blocks.isEmpty && savedCommands.isEmpty
                ? const Center(
                    child: Text(
                      'Noch keine Befehle über Terminal Master gesendet.',
                      style: TextStyle(fontSize: 10),
                    ),
                  )
                : ListView(
                    children: [
                      if (savedCommands.isNotEmpty) ...[
                        _commandHistorySection(
                          title: 'Gespeicherte Befehle',
                          trailing: TextButton.icon(
                            key: _paneKey('run-all-saved-commands'),
                            onPressed: session.hasActiveCommand
                                ? null
                                : () => _executeAllSavedCommands(savedCommands),
                            icon: const Icon(Icons.playlist_play, size: 15),
                            label: const Text('Alle'),
                          ),
                        ),
                        for (final command in savedCommands)
                          _buildSavedCommand(command),
                      ],
                      if (blocks.isNotEmpty) ...[
                        if (savedCommands.isNotEmpty)
                          _commandHistorySection(title: 'Aktuelle Sitzung'),
                        for (final block in blocks) _buildCommandBlock(block),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _commandHistorySection({required String title, Widget? trailing}) {
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: TerminalMasterColors.cyan,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildSavedCommand(SavedTerminalCommand command) {
    final keySuffix =
        '${command.executedAt.microsecondsSinceEpoch}-'
        '${command.command.hashCode}';
    return ListTile(
      key: Key('saved-terminal-command-$keySuffix'),
      dense: true,
      contentPadding: const EdgeInsets.only(left: 8, right: 2),
      minLeadingWidth: 0,
      horizontalTitleGap: 0,
      title: Text(
        command.command,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10),
      ),
      subtitle: Text(
        '${_formatTimestamp(command.executedAt)} · Exit ${command.exitCode ?? '?'}',
        style: const TextStyle(fontSize: 9),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('run-saved-terminal-command-$keySuffix'),
            tooltip: 'Direkt ausführen',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
            onPressed: session.hasActiveCommand
                ? null
                : () => _executeSavedCommand(command),
            icon: const Icon(Icons.play_arrow, size: 17),
          ),
          PopupMenuButton<String>(
            key: Key('saved-terminal-command-menu-$keySuffix'),
            tooltip: 'Weitere Aktionen',
            padding: EdgeInsets.zero,
            iconSize: 17,
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  widget.panelController.stageSavedCommand(
                    widget.pane.id,
                    command.command,
                  );
                case 'copy':
                  Clipboard.setData(ClipboardData(text: command.command));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
              PopupMenuItem(value: 'copy', child: Text('Kopieren')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _executeSavedCommand(SavedTerminalCommand command) async {
    final assessment = CommandRiskAssessor.assessRawCommands([
      command.command,
    ], containsRawConfiguration: false);
    if (assessment.requiresAcknowledgement) {
      final dialogContext = widget.navigatorKey.currentContext;
      if (dialogContext == null) return;
      final approved = await showCommandConfirmationDialog(
        dialogContext,
        commands: [command.command],
        assessment: assessment,
      );
      if (!approved) return;
    }
    try {
      await widget.panelController.executeSavedCommand(
        widget.pane.id,
        command.command,
      );
    } on Object catch (error) {
      _showCommandError(error);
    }
  }

  Future<void> _executeAllSavedCommands(
    List<SavedTerminalCommand> commands,
  ) async {
    final values = commands.reversed.map((command) => command.command).toList();
    final dialogContext = widget.navigatorKey.currentContext;
    if (dialogContext == null) return;
    final approved = await showCommandConfirmationDialog(
      dialogContext,
      commands: values,
      assessment: CommandRiskAssessor.assessRawCommands(
        values,
        containsRawConfiguration: false,
      ),
    );
    if (!approved) return;
    try {
      await widget.panelController.executeSavedCommands(widget.pane.id, values);
    } on Object catch (error) {
      _showCommandError(error);
    }
  }

  void _showCommandError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Ausführen fehlgeschlagen: $error')));
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}.${twoDigits(local.month)}. '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  Widget _buildCommandBlock(TerminalCommandBlock block) {
    final output = block.output;
    final displayedOutput = output.length > 10000
        ? '…\n${output.substring(output.length - 10000)}'
        : output;
    return ExpansionTile(
      key: Key('terminal-command-block-${block.id}'),
      dense: true,
      leading: Icon(
        _commandStatusIcon(block.status),
        size: 15,
        color: _commandStatusColor(block.status),
      ),
      title: Text(
        block.command,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10),
      ),
      subtitle: Text(
        '${_commandStatusText(block)} · ${_formatDuration(block.duration)}',
        style: const TextStyle(fontSize: 9),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
      children: [
        if (displayedOutput.isNotEmpty)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 110),
            padding: const EdgeInsets.all(8),
            color: TerminalMasterColors.background,
            child: SingleChildScrollView(
              child: SelectableText(
                displayedOutput,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        if (block.outputTruncated)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ausgabe wurde nach 500.000 Zeichen gekürzt.',
              style: TextStyle(color: TerminalMasterColors.yellow, fontSize: 9),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: block.command)),
              icon: const Icon(Icons.copy, size: 13),
              label: const Text('Befehl'),
            ),
            TextButton.icon(
              onPressed: output.isEmpty
                  ? null
                  : () => Clipboard.setData(ClipboardData(text: output)),
              icon: const Icon(Icons.content_copy, size: 13),
              label: const Text('Ausgabe'),
            ),
            TextButton.icon(
              onPressed: () => _exportCommandBlock(block),
              icon: const Icon(Icons.save_alt, size: 13),
              label: const Text('Export'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportCommandBlock(TerminalCommandBlock block) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Command Block exportieren',
      fileName: 'terminal-command-${block.id}.md',
    );
    if (path == null) return;
    try {
      await File(path).writeAsString(block.toMarkdown());
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export fehlgeschlagen: $error')));
    }
  }

  String _commandStatusText(TerminalCommandBlock block) {
    return switch (block.status) {
      TerminalCommandBlockStatus.running => 'Läuft',
      TerminalCommandBlockStatus.succeeded => 'Erfolgreich (Exit 0)',
      TerminalCommandBlockStatus.failed =>
        'Fehlgeschlagen (Exit ${block.exitCode ?? '?'})',
      TerminalCommandBlockStatus.interrupted => 'Unterbrochen',
    };
  }

  IconData _commandStatusIcon(TerminalCommandBlockStatus status) {
    return switch (status) {
      TerminalCommandBlockStatus.running => Icons.pending,
      TerminalCommandBlockStatus.succeeded => Icons.check_circle_outline,
      TerminalCommandBlockStatus.failed => Icons.error_outline,
      TerminalCommandBlockStatus.interrupted => Icons.cancel_outlined,
    };
  }

  Color _commandStatusColor(TerminalCommandBlockStatus status) {
    return switch (status) {
      TerminalCommandBlockStatus.running => TerminalMasterColors.yellow,
      TerminalCommandBlockStatus.succeeded => TerminalMasterColors.green,
      TerminalCommandBlockStatus.failed => TerminalMasterColors.red,
      TerminalCommandBlockStatus.interrupted => TerminalMasterColors.muted,
    };
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds >= 60) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds.remainder(60);
      return '${minutes}m ${seconds}s';
    }
    if (duration.inMilliseconds >= 1000) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    return '${duration.inMilliseconds}ms';
  }

  Future<void> _handleSecondaryTap(
    TapDownDetails details,
    CellOffset offset,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final localPosition = overlay.globalToLocal(details.globalPosition);
    final selectionText = _selectedText();
    final link = _linkAt(offset);
    final action = await showMenu<_TerminalMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        localPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        if (link != null)
          const PopupMenuItem(
            value: _TerminalMenuAction.openLink,
            child: ListTile(
              leading: Icon(Icons.open_in_new),
              title: Text('Link öffnen'),
            ),
          ),
        PopupMenuItem(
          value: _TerminalMenuAction.copy,
          enabled: selectionText != null,
          child: const ListTile(
            leading: Icon(Icons.copy_outlined),
            title: Text('Kopieren'),
          ),
        ),
        const PopupMenuItem(
          value: _TerminalMenuAction.paste,
          child: ListTile(
            leading: Icon(Icons.paste_outlined),
            title: Text('Einfügen'),
          ),
        ),
        const PopupMenuItem(
          value: _TerminalMenuAction.selectAll,
          child: ListTile(
            leading: Icon(Icons.select_all),
            title: Text('Alles auswählen'),
          ),
        ),
        PopupMenuItem(
          value: _TerminalMenuAction.searchSelection,
          enabled: selectionText != null,
          child: const ListTile(
            leading: Icon(Icons.search),
            title: Text('Auswahl suchen'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _TerminalMenuAction.clearOutput,
          child: ListTile(
            leading: Icon(Icons.cleaning_services_outlined),
            title: Text('Ausgabe leeren'),
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _TerminalMenuAction.openLink:
        if (link != null) await _openLink(link);
        break;
      case _TerminalMenuAction.copy:
        if (selectionText != null) {
          await Clipboard.setData(ClipboardData(text: selectionText));
        }
        break;
      case _TerminalMenuAction.paste:
        final data = await Clipboard.getData('text/plain');
        if (data?.text case final text?) await _paste(text);
        break;
      case _TerminalMenuAction.selectAll:
        _selectAll();
        break;
      case _TerminalMenuAction.searchSelection:
        if (selectionText != null) _searchForSelection(selectionText);
        break;
      case _TerminalMenuAction.clearOutput:
        _clearOutput();
        break;
    }
  }

  void _handleTerminalTap(TapUpDetails details, CellOffset offset) {
    final isShortcut =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!isShortcut) return;
    final link = _linkAt(offset);
    if (link != null) _openLink(link);
  }

  String? _selectedText() {
    final selection = _terminalController.selection;
    if (selection == null) return null;
    final text = session.terminal.buffer.getText(selection);
    return text.isEmpty ? null : text;
  }

  Uri? _linkAt(CellOffset offset) {
    final oscLink = session.hyperlinkAt(offset);
    if (oscLink != null && ExternalUrlLauncher.isSupported(oscLink)) {
      return oscLink;
    }
    if (offset.y < 0 || offset.y >= session.terminal.buffer.height) return null;

    final line = _readLine(session.terminal.buffer.lines[offset.y]);
    final pattern = RegExp(r'''(?:https?://|mailto:)[^\s<>"']+''');
    for (final match in pattern.allMatches(line.text)) {
      var value = match.group(0)!;
      while (value.isNotEmpty && '.,;:)]}'.contains(value[value.length - 1])) {
        value = value.substring(0, value.length - 1);
      }
      final begin = line.columns[match.start];
      final end = line.columns[match.start + value.length];
      if (begin != null && end != null && offset.x >= begin && offset.x < end) {
        final uri = Uri.tryParse(value);
        if (uri != null && ExternalUrlLauncher.isSupported(uri)) return uri;
      }
    }
    return null;
  }

  Future<void> _openLink(Uri uri) async {
    try {
      await ExternalUrlLauncher.open(uri);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link konnte nicht geöffnet werden: $error')),
      );
    }
  }

  void _selectAll() {
    final buffer = session.terminal.buffer;
    if (buffer.height == 0) return;
    final lastLine = buffer.lines[buffer.height - 1];
    _terminalController.setSelection(
      buffer.createAnchor(0, 0),
      buffer.createAnchor(lastLine.getTrimmedLength(), buffer.height - 1),
    );
  }

  void _searchForSelection(String selection) {
    final query = selection.trim().split(RegExp(r'[\r\n]')).first;
    if (query.isEmpty) return;
    _searchController.text = query;
    widget.panelController.openSearch(widget.pane.id);
    _runSearch();
  }

  void _clearOutput() {
    _terminalController.clearSelection();
    _clearSearchHighlights();
    session.terminal.write('\x1b[2J\x1b[3J\x1b[H');
    if (_searchController.text.isNotEmpty) _runSearch();
  }

  KeyEventResult _handleTerminalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isShortcut =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isShortcut && key == LogicalKeyboardKey.keyF) {
      widget.panelController.openSearch(widget.pane.id);
      return KeyEventResult.handled;
    }
    if (isShortcut &&
        (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add)) {
      widget.panelController.zoomIn();
      return KeyEventResult.handled;
    }
    if (isShortcut &&
        (key == LogicalKeyboardKey.minus ||
            key == LogicalKeyboardKey.numpadSubtract)) {
      widget.panelController.zoomOut();
      return KeyEventResult.handled;
    }
    if (isShortcut &&
        (key == LogicalKeyboardKey.digit0 ||
            key == LogicalKeyboardKey.numpad0)) {
      widget.panelController.resetZoom();
      return KeyEventResult.handled;
    }
    if (isShortcut && key == LogicalKeyboardKey.keyV) {
      Clipboard.getData('text/plain').then((data) {
        if (data?.text case final text?) _paste(text);
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final isAtBottom = _scrollController.position.extentAfter <= 1;
    if (_isAtBottom != isAtBottom && mounted) {
      setState(() => _isAtBottom = isAtBottom);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _scheduleSearchRefresh() {
    if (_searchController.text.isEmpty || _searchRefreshScheduled) return;
    _searchRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchRefreshScheduled = false;
      if (mounted) _runSearch(preserveActiveMatch: true);
    });
  }

  void _runSearch({bool preserveActiveMatch = false}) {
    final previousMatch =
        preserveActiveMatch &&
            _activeSearchMatch >= 0 &&
            _activeSearchMatch < _searchMatches.length
        ? _searchMatches[_activeSearchMatch]
        : null;
    _clearSearchHighlights();
    final query = _searchController.text;
    final matches = query.isEmpty ? <_TerminalSearchMatch>[] : _find(query);
    var activeMatch = matches.isEmpty ? -1 : 0;
    if (previousMatch != null) {
      final previousIndex = matches.indexOf(previousMatch);
      if (previousIndex >= 0) activeMatch = previousIndex;
    }
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      _searchHighlights.add(
        _terminalController.highlight(
          p1: session.terminal.buffer.createAnchorFromOffset(match.begin),
          p2: session.terminal.buffer.createAnchorFromOffset(match.end),
          color: index == activeMatch
              ? const Color(0xaaff8b3d)
              : const Color(0x77ffc857),
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _searchMatches = matches;
      _activeSearchMatch = activeMatch;
    });
    if (activeMatch >= 0) _scrollToSearchMatch(matches[activeMatch]);
  }

  List<_TerminalSearchMatch> _find(String query) {
    final matches = <_TerminalSearchMatch>[];
    final normalizedQuery = query.toLowerCase();
    final buffer = session.terminal.buffer;
    for (var y = 0; y < buffer.height; y++) {
      final line = _readLine(buffer.lines[y]);
      final value = line.text;
      final normalizedValue = value.toLowerCase();
      if (normalizedValue.length != value.length) continue;
      var start = 0;
      while (start <= normalizedValue.length - normalizedQuery.length) {
        final index = normalizedValue.indexOf(normalizedQuery, start);
        if (index < 0) break;
        final beginColumn = line.columns[index];
        final endColumn = line.columns[index + normalizedQuery.length];
        if (beginColumn != null && endColumn != null) {
          matches.add(
            _TerminalSearchMatch(
              CellOffset(beginColumn, y),
              CellOffset(endColumn, y),
            ),
          );
        }
        start = index + normalizedQuery.length;
      }
    }
    return matches;
  }

  _TerminalLineText _readLine(BufferLine line) {
    final text = StringBuffer();
    final columns = <int, int>{0: 0};
    for (var x = 0; x < line.length; x++) {
      final codePoint = line.getCodePoint(x);
      if (codePoint == 0) continue;
      columns[text.length] = x;
      text.writeCharCode(codePoint);
      columns[text.length] = x + line.getWidth(x).clamp(1, 2);
    }
    return _TerminalLineText(text.toString(), columns);
  }

  void _nextSearchMatch() => _activateSearchMatch(1);

  void _previousSearchMatch() => _activateSearchMatch(-1);

  void _activateSearchMatch(int direction) {
    if (_searchMatches.isEmpty) return;
    final next = (_activeSearchMatch + direction) % _searchMatches.length;
    _activeSearchMatch = next < 0 ? next + _searchMatches.length : next;
    _runSearch(preserveActiveMatch: true);
  }

  void _scrollToSearchMatch(_TerminalSearchMatch match) {
    if (!_scrollController.hasClients) return;
    final lineHeight =
        _terminalViewKey.currentState?.renderTerminal.lineHeight ??
        widget.panelController.fontSize * 1.2;
    final viewportHeight = _scrollController.position.viewportDimension;
    final target = match.begin.y * lineHeight - viewportHeight / 2;
    _scrollController.jumpTo(
      target.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      ),
    );
  }

  void _clearSearchHighlights() {
    for (final highlight in _searchHighlights) {
      highlight.dispose();
    }
    _searchHighlights.clear();
  }

  Future<void> _paste(String text) async {
    if (!mounted) return;
    if (text.contains('\n') || text.contains('\r')) {
      final dialogContext = widget.navigatorKey.currentContext;
      if (dialogContext == null) return;
      final approved =
          await showDialog<bool>(
            context: dialogContext,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded),
              title: const Text('Mehrzeiligen Text einfügen?'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 640,
                  maxHeight: 360,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Zeilenumbrüche können Befehle unmittelbar ausführen. '
                      'Prüfe den Inhalt vor dem Einfügen.',
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(child: SelectableText(text)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Einfügen'),
                ),
              ],
            ),
          ) ??
          false;
      if (!approved || !mounted) return;
    }
    session.terminal.paste(text);
  }

  String _statusText(TerminalSession session) {
    return switch (session.status) {
      TerminalSessionStatus.idle => 'Bereit',
      TerminalSessionStatus.starting => 'Terminal wird gestartet ...',
      TerminalSessionStatus.running => 'Terminal läuft',
      TerminalSessionStatus.exited =>
        'Prozess beendet (${session.exitCode ?? 'unbekannt'})',
      TerminalSessionStatus.failed =>
        'Terminal konnte nicht gestartet werden: ${session.error}',
    };
  }

  String _statusTitle() {
    if (session.status == TerminalSessionStatus.exited ||
        session.status == TerminalSessionStatus.failed) {
      return _statusText(session);
    }
    return session.title ?? _statusText(session);
  }

  String _sessionDetails() {
    final directory = session.workingDirectory;
    return directory == null
        ? session.shellName
        : '${session.shellName} · $directory';
  }

  String _statusTooltip() {
    final details = <String>[
      _statusTitle(),
      'Shell: ${session.shellName}',
      if (session.workingDirectory case final directory?)
        'Verzeichnis: $directory',
      'Status: ${_statusText(session)}',
    ];
    return details.join('\n');
  }

  Key _paneKey(String value) =>
      widget.panelController.activePane.id == widget.pane.id
      ? Key(value)
      : Key('$value-${widget.pane.id}');

  IconData _statusIcon(TerminalSessionStatus status) {
    return switch (status) {
      TerminalSessionStatus.idle => Icons.circle_outlined,
      TerminalSessionStatus.starting => Icons.pending,
      TerminalSessionStatus.running => Icons.circle,
      TerminalSessionStatus.exited => Icons.stop_circle_outlined,
      TerminalSessionStatus.failed => Icons.error_outline,
    };
  }

  Color _statusColor(TerminalSessionStatus status) {
    return switch (status) {
      TerminalSessionStatus.idle => Colors.blueGrey,
      TerminalSessionStatus.starting => Colors.amber,
      TerminalSessionStatus.running => TerminalMasterColors.green,
      TerminalSessionStatus.exited => Colors.blueGrey,
      TerminalSessionStatus.failed => Colors.redAccent,
    };
  }
}

class _TerminalSearchMatch {
  final CellOffset begin;
  final CellOffset end;

  const _TerminalSearchMatch(this.begin, this.end);

  @override
  bool operator ==(Object other) =>
      other is _TerminalSearchMatch && begin == other.begin && end == other.end;

  @override
  int get hashCode => Object.hash(begin, end);
}

class _TerminalLineText {
  final String text;
  final Map<int, int> columns;

  const _TerminalLineText(this.text, this.columns);
}

enum _TerminalMenuAction {
  openLink,
  copy,
  paste,
  selectAll,
  searchSelection,
  clearOutput,
}
