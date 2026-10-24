part of '../terminal_panel.dart';

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

/// Why a terminal tab operation was rejected.
///
/// The controller is a `ChangeNotifier` with no `BuildContext`, so it reports a
/// code and the UI renders it in the active language.
enum TerminalTabFailure {
  unknownProfile,
  savedTabsUnreadable,
  sshTabsCannotBeSnapshotted,
  nameMustNotBeEmpty,
  savedTabChangedMeanwhile,
  invalidTabName,
  integratedTerminalUnavailable,
  shellProfileUnavailable,
}

class TerminalTabException implements Exception {
  final TerminalTabFailure failure;

  /// The profile id or nested error the failure refers to, when it has one.
  final String? detail;

  const TerminalTabException(this.failure, [this.detail]);

  /// Developer-facing English description; the UI renders the localized form.
  String get message => switch (failure) {
    TerminalTabFailure.unknownProfile => 'unknown profile',
    TerminalTabFailure.savedTabsUnreadable =>
      'Saved tabs could not be loaded: $detail',
    TerminalTabFailure.sshTabsCannotBeSnapshotted =>
      'SSH terminal tabs cannot be stored as a terminal snapshot for security '
          'reasons.',
    TerminalTabFailure.nameMustNotBeEmpty => 'The name must not be empty.',
    TerminalTabFailure.savedTabChangedMeanwhile =>
      'This saved tab changed in the meantime. Open the current version again.',
    TerminalTabFailure.invalidTabName => 'Invalid terminal tab name.',
    TerminalTabFailure.integratedTerminalUnavailable =>
      'The built-in terminal is not available.',
    TerminalTabFailure.shellProfileUnavailable =>
      'The shell profile "$detail" is not available.',
  };

  @override
  String toString() => message;
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
  TerminalTabException? _savedTabsError;
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
  TerminalTabException? get savedTabsError => _savedTabsError;
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
      throw const TerminalTabException(TerminalTabFailure.unknownProfile);
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
      _savedTabsError = TerminalTabException(
        TerminalTabFailure.savedTabsUnreadable,
        '$error',
      );
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
    if (_savedTabsError case final error?) throw error;
    if (tab.panes.any((pane) => pane.profile.isSsh)) {
      throw const TerminalTabException(
        TerminalTabFailure.sshTabsCannotBeSnapshotted,
      );
    }
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const TerminalTabException(TerminalTabFailure.nameMustNotBeEmpty);
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
      throw const TerminalTabException(
        TerminalTabFailure.savedTabChangedMeanwhile,
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
    if (_savedTabsError case final error?) throw error;
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
    if (_savedTabsError case final error?) throw error;
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
      throw const TerminalTabException(TerminalTabFailure.invalidTabName);
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
      final sessionError = activeSession.error;
      throw sessionError == null
          ? const TerminalTabException(
              TerminalTabFailure.integratedTerminalUnavailable,
            )
          : StateError(sessionError);
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
      throw TerminalTabException(
        TerminalTabFailure.shellProfileUnavailable,
        snapshot.profileId,
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
