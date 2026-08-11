import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../models/shell_profile.dart';
import '../models/terminal_command_block.dart';
import '../services/terminal_backend.dart';
import '../services/external_url_launcher.dart';
import '../services/terminal_session.dart';
import '../theme.dart';
import 'terminal_mouse_overlay.dart';

enum TerminalSplitOrientation { vertical, horizontal }

class TerminalPaneData {
  final String id;
  final ShellProfile profile;
  final int row;
  final int column;
  final TextEditingController commandController = TextEditingController();
  TerminalSession session;
  bool isSearchOpen = false;

  TerminalPaneData({
    required this.id,
    required this.profile,
    required this.row,
    required this.column,
    required this.session,
  });

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
  TerminalPaneData get activePane => panes.firstWhere(
    (pane) => pane.id == focusedPaneId,
    orElse: () => primaryPane,
  );

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

  final TerminalBackendFactory backendFactory;
  final GlobalKey<NavigatorState> navigatorKey;
  final List<ShellProfile> profiles;

  TerminalPanelController({
    required this.backendFactory,
    required this.navigatorKey,
    List<ShellProfile>? profiles,
  }) : profiles = List.unmodifiable(
         profiles == null || profiles.isEmpty
             ? ShellProfile.platformDefaults()
             : profiles,
       ) {
    final tab = _newTab(this.profiles.first);
    _tabs.add(tab);
    _activeTabId = tab.id;
  }

  final List<TerminalTab> _tabs = [];
  var _nextTabId = 1;
  var _nextPaneId = 1;
  late String _activeTabId;
  bool _isOpen = false;
  bool _isMaximized = false;
  double _fontSize = defaultFontSize;
  bool _disposed = false;

  List<TerminalTab> get tabs => List.unmodifiable(_tabs);
  TerminalTab get activeTab => _tab(_activeTabId);
  TerminalPaneData get activePane => activeTab.activePane;
  TerminalPaneData get primaryPane => activeTab.primaryPane;
  List<TerminalPaneData> get visiblePanes => activeTab.visiblePanes;
  TerminalSession get session => activePane.session;
  TextEditingController get commandController => activePane.commandController;
  ShellProfile get activeProfile => activePane.profile;

  bool get isOpen => _isOpen;
  bool get isMaximized => _isMaximized;
  bool get isSearchOpen => activePane.isSearchOpen;
  bool get isSplit =>
      activeTab.isVerticallySplit || activeTab.isHorizontallySplit;
  bool hasSplit(TerminalSplitOrientation orientation) =>
      activeTab.hasSplit(orientation);
  double get fontSize => _fontSize;

  Future<void> open() async {
    if (!_isOpen) {
      _isOpen = true;
      notifyListeners();
    }
    await Future.wait(visiblePanes.map(_startForDisplay));
  }

  void hide() {
    if (!_isOpen) return;
    _isOpen = false;
    _isMaximized = false;
    notifyListeners();
  }

  Future<void> toggle() => _isOpen ? Future.sync(hide) : open();

  void toggleMaximized() {
    if (!_isOpen) return;
    _isMaximized = !_isMaximized;
    notifyListeners();
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
    if (_isOpen) await _startForDisplay(tab.primaryPane);
  }

  Future<void> selectTab(String tabId) async {
    if (!_tabs.any((tab) => tab.id == tabId)) return;
    _activeTabId = tabId;
    notifyListeners();
    if (_isOpen) {
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
    notifyListeners();
    if (_isOpen) await Future.wait(tab.visiblePanes.map(_startForDisplay));
  }

  void closeTab(String tabId) {
    if (_tabs.length == 1) return;
    final tab = _tab(tabId);
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
    pane.session.removeListener(_handleSessionUpdate);
    pane.session.dispose();
    pane.session = _newSession(pane.profile);
    notifyListeners();
    if (_isOpen && _isVisiblePane(activeTab, paneId)) {
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
    _isOpen = true;
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

  Future<void> stopSession([String? paneId]) async {
    final activeSession = _pane(paneId ?? activePane.id).session;
    if (!activeSession.isRunning) return;
    await activeSession.stop();
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
      tab.id == _activeTabId && tab.visiblePanes.any((pane) => pane.id == id);

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

class TerminalPanelToggleButton extends StatelessWidget {
  const TerminalPanelToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TerminalPanelScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return IconButton(
      key: const Key('terminal-panel-toggle'),
      icon: const Icon(Icons.terminal),
      tooltip: controller.isOpen
          ? 'Terminal einklappen'
          : 'Terminal ausklappen',
      onPressed: controller.toggle,
    );
  }
}

class TerminalWorkspace extends StatefulWidget {
  final TerminalBackendFactory backendFactory;
  final GlobalKey<NavigatorState> navigatorKey;
  final List<ShellProfile>? profiles;
  final Widget child;

  const TerminalWorkspace({
    super.key,
    required this.backendFactory,
    required this.navigatorKey,
    this.profiles,
    required this.child,
  });

  @override
  State<TerminalWorkspace> createState() => _TerminalWorkspaceState();
}

class _TerminalWorkspaceState extends State<TerminalWorkspace> {
  late final TerminalPanelController _controller;
  double _panelWidth = 520;

  @override
  void initState() {
    super.initState();
    _controller = TerminalPanelController(
      backendFactory: widget.backendFactory,
      navigatorKey: widget.navigatorKey,
      profiles: widget.profiles,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TerminalPanelScope(
      controller: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => LayoutBuilder(
          builder: (context, constraints) {
            final maxPanelWidth = constraints.maxWidth * 0.7;
            final minPanelWidth = maxPanelWidth < 280 ? maxPanelWidth : 280.0;
            final panelWidth = _controller.isMaximized
                ? constraints.maxWidth
                : _panelWidth.clamp(minPanelWidth, maxPanelWidth);
            final reservedPanelWidth =
                _controller.isOpen && !_controller.isMaximized
                ? panelWidth + 6
                : 0.0;
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  right: reservedPanelWidth,
                  child: widget.child,
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: panelWidth,
                  child: Offstage(
                    offstage: !_controller.isOpen,
                    child: IgnorePointer(
                      ignoring: !_controller.isOpen,
                      child: SizedBox(
                        key: const Key('terminal-side-panel'),
                        child: Material(
                          color: TerminalMasterColors.background,
                          child: TerminalPanel(controller: _controller),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_controller.isOpen && !_controller.isMaximized)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: panelWidth,
                    width: 6,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _panelWidth = (_panelWidth - details.delta.dx)
                                .clamp(minPanelWidth, maxPanelWidth);
                          });
                        },
                        child: Container(color: TerminalMasterColors.border),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
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
    final session = controller.session;
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.only(left: 14, right: 4),
          color: TerminalMasterColors.surfaceRaised,
          child: Row(
            children: [
              const Icon(Icons.terminal, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Terminal',
                  style: TextStyle(
                    color: TerminalMasterColors.yellow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                key: const Key('terminal-search-toggle'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                tooltip: controller.isSearchOpen
                    ? 'Suche schließen'
                    : 'Terminal durchsuchen',
                onPressed: controller.toggleSearch,
                icon: Icon(
                  controller.isSearchOpen ? Icons.search_off : Icons.search,
                ),
              ),
              if ((session.status == TerminalSessionStatus.exited ||
                      session.status == TerminalSessionStatus.failed) &&
                  !session.isRunning)
                IconButton(
                  key: const Key('restart-terminal-tab'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  tooltip: 'Sitzung neu starten',
                  onPressed: () => controller.restartPane(pane.id),
                  icon: const Icon(Icons.restart_alt),
                ),
              IconButton(
                key: const Key('maximize-terminal-panel'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                tooltip: controller.isMaximized
                    ? 'Terminal verkleinern'
                    : 'Terminal maximieren',
                onPressed: controller.toggleMaximized,
                icon: Icon(
                  controller.isMaximized
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                ),
              ),
              if (session.status != TerminalSessionStatus.exited &&
                  session.status != TerminalSessionStatus.failed)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  tooltip: 'Terminal-Sitzung beenden',
                  onPressed: session.isRunning
                      ? () => _confirmStop(context, pane.id)
                      : null,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
              IconButton(
                key: const Key('hide-terminal-panel'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                onPressed: controller.hide,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        _buildTabBar(context),
        Expanded(child: _buildPanes()),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
          decoration: const BoxDecoration(
            color: TerminalMasterColors.surface,
            border: Border(top: BorderSide(color: TerminalMasterColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
                onPressed: controller.sendPending,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
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
              children: controller.tabs.map((tab) {
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
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                pane.session.title ?? pane.profile.name,
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
                            IconButton(
                              tooltip: 'Tab schließen',
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
              }).toList(),
            ),
          ),
          PopupMenuButton<ShellProfile>(
            key: const Key('new-terminal-tab'),
            tooltip: 'Neuer Terminal-Tab',
            icon: const Icon(Icons.add, size: 19),
            onSelected: controller.createTab,
            itemBuilder: (context) => controller.profiles
                .map(
                  (profile) =>
                      PopupMenuItem(value: profile, child: Text(profile.name)),
                )
                .toList(),
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
        final verticalOffset = constraints.maxWidth / 2;
        final horizontalOffset = constraints.maxHeight / 2;
        return Stack(
          children: [
            for (final tab in controller.tabs)
              for (final pane in tab.panes)
                Positioned(
                  key: Key('terminal-pane-position-${pane.id}'),
                  top: pane.row == 1 && isHorizontallySplit
                      ? horizontalOffset + 3
                      : 0,
                  bottom: pane.row == 0 && isHorizontallySplit
                      ? horizontalOffset + 3
                      : 0,
                  left: pane.column == 1 && isVerticallySplit
                      ? verticalOffset + 3
                      : 0,
                  right: pane.column == 0 && isVerticallySplit
                      ? verticalOffset + 3
                      : 0,
                  child: Offstage(
                    offstage:
                        tab.id != activeTabId ||
                        !tab.visiblePanes.contains(pane),
                    child: IgnorePointer(
                      ignoring:
                          tab.id != activeTabId ||
                          !tab.visiblePanes.contains(pane),
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
            if (isHorizontallySplit)
              Positioned(
                left: 0,
                right: 0,
                top: horizontalOffset,
                height: 6,
                child: Container(color: TerminalMasterColors.border),
              ),
            if (isVerticallySplit)
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

  Future<void> _confirmStop(BuildContext context, String paneId) async {
    final dialogContext = controller.navigatorKey.currentContext;
    if (dialogContext == null) return;
    final approved =
        await showDialog<bool>(
          context: dialogContext,
          builder: (context) => AlertDialog(
            title: const Text('Terminal-Sitzung beenden?'),
            content: const Text(
              'Ein laufender Prozess wird unterbrochen. Das Panel und noch '
              'nicht gesendete Befehle bleiben erhalten.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sitzung beenden'),
              ),
            ],
          ),
        ) ??
        false;
    if (approved) await controller.stopSession(paneId);
  }

  Future<void> _confirmClose(BuildContext context, TerminalTab tab) async {
    if (!tab.panes.any((pane) => pane.session.isRunning)) {
      controller.closeTab(tab.id);
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
    if (approved) controller.closeTab(tab.id);
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
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
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
                Text('${blocks.length}', style: const TextStyle(fontSize: 10)),
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
            child: blocks.isEmpty
                ? const Center(
                    child: Text(
                      'Noch keine Befehle über Terminal Master gesendet.',
                      style: TextStyle(fontSize: 10),
                    ),
                  )
                : ListView.builder(
                    itemCount: blocks.length,
                    itemBuilder: (context, index) =>
                        _buildCommandBlock(blocks[index]),
                  ),
          ),
        ],
      ),
    );
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

    if (key == LogicalKeyboardKey.f11) {
      widget.panelController.toggleMaximized();
      return KeyEventResult.handled;
    }
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
