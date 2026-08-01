import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../services/terminal_backend.dart';
import '../services/terminal_session.dart';
import '../theme.dart';
import 'terminal_mouse_overlay.dart';

class TerminalPanelController extends ChangeNotifier {
  static const minFontSize = 9.0;
  static const maxFontSize = 24.0;
  static const defaultFontSize = 13.0;

  final TerminalBackendFactory backendFactory;
  final GlobalKey<NavigatorState> navigatorKey;
  final TextEditingController commandController = TextEditingController();

  TerminalPanelController({
    required this.backendFactory,
    required this.navigatorKey,
  });

  TerminalSession? _session;
  bool _isOpen = false;
  bool _isMaximized = false;
  bool _isSearchOpen = false;
  double _fontSize = defaultFontSize;
  bool _disposed = false;

  TerminalSession? get session => _session;

  bool get isOpen => _isOpen;
  bool get isMaximized => _isMaximized;
  bool get isSearchOpen => _isSearchOpen;
  double get fontSize => _fontSize;

  Future<void> open() async {
    if (!_isOpen) {
      _isOpen = true;
      notifyListeners();
    }
    try {
      await _ensureSession();
    } on Object {
      // Startup errors are rendered inside the panel.
    }
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

  void toggleSearch() {
    _isSearchOpen = !_isSearchOpen;
    notifyListeners();
  }

  void openSearch() {
    if (_isSearchOpen) return;
    _isSearchOpen = true;
    notifyListeners();
  }

  void closeSearch() {
    if (!_isSearchOpen) return;
    _isSearchOpen = false;
    notifyListeners();
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
    _isOpen = true;
    notifyListeners();
    await _ensureSession();
    final current = commandController.text;
    commandController.text = current.isEmpty ? command : '$current\n$command';
    commandController.selection = TextSelection.collapsed(
      offset: commandController.text.length,
    );
  }

  Future<void> sendPending() async {
    final command = commandController.text;
    if (command.trim().isEmpty) return;
    final activeSession = await _ensureSession();
    commandController.clear();
    try {
      activeSession.sendCommand(command);
    } on Object {
      commandController.text = command;
      rethrow;
    }
  }

  Future<void> stopSession() async {
    final activeSession = _session;
    if (activeSession == null || !activeSession.isRunning) return;
    await activeSession.stop();
  }

  Future<TerminalSession> _ensureSession() async {
    var activeSession = _session;
    if (activeSession == null ||
        activeSession.status == TerminalSessionStatus.exited ||
        (activeSession.status == TerminalSessionStatus.failed &&
            !activeSession.isRunning)) {
      activeSession?.dispose();
      activeSession = TerminalSession(backendFactory: backendFactory);
      _session = activeSession;
      notifyListeners();
    }
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

  @override
  void dispose() {
    _disposed = true;
    commandController.dispose();
    _session?.dispose();
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
  final Widget child;

  const TerminalWorkspace({
    super.key,
    required this.backendFactory,
    required this.navigatorKey,
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
                if (_controller.isOpen)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: panelWidth,
                    child: SizedBox(
                      key: const Key('terminal-side-panel'),
                      child: Material(
                        color: TerminalMasterColors.background,
                        child: TerminalPanel(controller: _controller),
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
    final session = controller.session;
    return Column(
      children: [
        AnimatedBuilder(
          animation: session ?? controller,
          builder: (context, child) => Container(
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
                  tooltip: controller.isSearchOpen
                      ? 'Suche schließen'
                      : 'Terminal durchsuchen',
                  onPressed: controller.toggleSearch,
                  icon: Icon(
                    controller.isSearchOpen ? Icons.search_off : Icons.search,
                  ),
                ),
                IconButton(
                  key: const Key('maximize-terminal-panel'),
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
                IconButton(
                  tooltip: 'Terminal-Sitzung beenden',
                  onPressed: session?.isRunning == true
                      ? () => _confirmStop(context)
                      : null,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
                IconButton(
                  key: const Key('hide-terminal-panel'),
                  onPressed: controller.hide,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: session == null
              ? const Center(child: CircularProgressIndicator())
              : TerminalPane(
                  key: ValueKey(session),
                  session: session,
                  panelController: controller,
                  navigatorKey: controller.navigatorKey,
                ),
        ),
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
                  decoration: const InputDecoration(
                    hintText: 'Befehle aus YAML erscheinen hier ...',
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

  Future<void> _confirmStop(BuildContext context) async {
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
    if (approved) await controller.stopSession();
  }
}

class TerminalPane extends StatefulWidget {
  final TerminalSession session;
  final TerminalPanelController panelController;
  final GlobalKey<NavigatorState> navigatorKey;

  const TerminalPane({
    super.key,
    required this.session,
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

  TerminalSession get session => widget.session;

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
    final isSearchOpen = widget.panelController.isSearchOpen;
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
            child: Row(
              children: [
                Icon(
                  _statusIcon(session.status),
                  size: 13,
                  color: _statusColor(session.status),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: session.title ?? _statusText(session),
                    child: Text(
                      session.title ?? _statusText(session),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: session.title == null
                            ? TerminalMasterColors.cyan
                            : TerminalMasterColors.yellow,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const Tooltip(
                  message: 'xterm-256color mit 24-Bit-True-Color',
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.palette_outlined,
                      key: Key('terminal-true-color-indicator'),
                      size: 14,
                      color: TerminalMasterColors.cyan,
                    ),
                  ),
                ),
                if (session.terminal.isUsingAltBuffer)
                  const Tooltip(
                    message: 'Alternate Screen aktiv',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.layers_outlined,
                        key: Key('terminal-alt-screen-indicator'),
                        size: 14,
                        color: TerminalMasterColors.yellow,
                      ),
                    ),
                  ),
                if (session.terminal.mouseMode != MouseMode.none)
                  const Tooltip(
                    message: 'Terminal-Maussteuerung aktiv',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.mouse_outlined,
                        key: Key('terminal-mouse-mode-indicator'),
                        size: 14,
                        color: TerminalMasterColors.green,
                      ),
                    ),
                  ),
                _compactIconButton(
                  key: const Key('terminal-zoom-out'),
                  tooltip: 'Verkleinern',
                  icon: Icons.remove,
                  onPressed: widget.panelController.zoomOut,
                ),
                TextButton(
                  key: const Key('terminal-zoom-reset'),
                  onPressed: widget.panelController.resetZoom,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(42, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: Text('${widget.panelController.fontSize.round()} px'),
                ),
                _compactIconButton(
                  key: const Key('terminal-zoom-in'),
                  tooltip: 'Vergrößern',
                  icon: Icons.add,
                  onPressed: widget.panelController.zoomIn,
                ),
              ],
            ),
          ),
        ),
        if (isSearchOpen) _buildSearchBar(),
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
                    onSecondaryTapDown: _handleSecondaryTap,
                    onKeyEvent: _handleTerminalKey,
                  ),
                ),
              ),
              if (session.terminal.mouseMode != MouseMode.none)
                Positioned.fill(
                  child: TerminalMouseOverlay(
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
                    key: const Key('terminal-scroll-to-bottom'),
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
    required VoidCallback onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
    );
  }

  Widget _buildSearchBar() {
    final resultText = _searchMatches.isEmpty
        ? '0 Treffer'
        : '${_activeSearchMatch + 1}/${_searchMatches.length}';
    return Container(
      key: const Key('terminal-search-bar'),
      color: TerminalMasterColors.surfaceRaised,
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('terminal-search-input'),
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
            key: const Key('terminal-search-previous'),
            tooltip: 'Vorheriger Treffer',
            icon: Icons.keyboard_arrow_up,
            onPressed: _previousSearchMatch,
          ),
          _compactIconButton(
            key: const Key('terminal-search-next'),
            tooltip: 'Nächster Treffer',
            icon: Icons.keyboard_arrow_down,
            onPressed: _nextSearchMatch,
          ),
          _compactIconButton(
            key: const Key('terminal-search-close'),
            tooltip: 'Suche schließen',
            icon: Icons.close,
            onPressed: widget.panelController.closeSearch,
          ),
        ],
      ),
    );
  }

  Future<void> _handleSecondaryTap(
    TapDownDetails details,
    CellOffset offset,
  ) async {
    final selection = _terminalController.selection;
    if (selection != null) {
      final text = session.terminal.buffer.getText(selection);
      _terminalController.clearSelection();
      await Clipboard.setData(ClipboardData(text: text));
      return;
    }
    final data = await Clipboard.getData('text/plain');
    if (data?.text case final text?) await _paste(text);
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
      widget.panelController.openSearch();
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
      final line = buffer.lines[y];
      final text = StringBuffer();
      final columns = <int, int>{0: 0};
      for (var x = 0; x < line.length; x++) {
        final codePoint = line.getCodePoint(x);
        if (codePoint == 0) continue;
        columns[text.length] = x;
        text.writeCharCode(codePoint);
        columns[text.length] = x + line.getWidth(x).clamp(1, 2);
      }
      final value = text.toString();
      final normalizedValue = value.toLowerCase();
      if (normalizedValue.length != value.length) continue;
      var start = 0;
      while (start <= normalizedValue.length - normalizedQuery.length) {
        final index = normalizedValue.indexOf(normalizedQuery, start);
        if (index < 0) break;
        final beginColumn = columns[index];
        final endColumn = columns[index + normalizedQuery.length];
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
