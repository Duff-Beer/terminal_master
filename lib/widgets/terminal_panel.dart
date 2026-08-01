import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../services/terminal_backend.dart';
import '../services/terminal_session.dart';

class TerminalPanelController extends ChangeNotifier {
  final TerminalBackendFactory backendFactory;
  final GlobalKey<NavigatorState> navigatorKey;
  final TextEditingController commandController = TextEditingController();

  TerminalPanelController({
    required this.backendFactory,
    required this.navigatorKey,
  });

  TerminalSession? _session;
  bool _isOpen = false;
  bool _disposed = false;

  TerminalSession? get session => _session;

  bool get isOpen => _isOpen;

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
    notifyListeners();
  }

  Future<void> toggle() => _isOpen ? Future.sync(hide) : open();

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
            final panelWidth = _panelWidth.clamp(minPanelWidth, maxPanelWidth);
            return Row(
              children: [
                Expanded(child: widget.child),
                if (_controller.isOpen)
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _panelWidth = (_panelWidth - details.delta.dx).clamp(
                            minPanelWidth,
                            maxPanelWidth,
                          );
                        });
                      },
                      child: Container(
                        width: 6,
                        color: const Color(0xff31506d),
                      ),
                    ),
                  ),
                if (_controller.isOpen)
                  SizedBox(
                    key: const Key('terminal-side-panel'),
                    width: panelWidth,
                    child: Material(
                      color: const Color(0xff07111e),
                      child: TerminalPanel(controller: _controller),
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
            color: const Color(0xff10263a),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Terminal',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
                  navigatorKey: controller.navigatorKey,
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
          decoration: const BoxDecoration(
            color: Color(0xff0b1b2b),
            border: Border(top: BorderSide(color: Color(0xff31506d))),
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
  final GlobalKey<NavigatorState> navigatorKey;

  const TerminalPane({
    super.key,
    required this.session,
    required this.navigatorKey,
  });

  @override
  State<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends State<TerminalPane> {
  final _terminalController = TerminalController();

  TerminalSession get session => widget.session;

  static const _terminalTheme = TerminalTheme(
    cursor: Color(0xff54f1b5),
    selection: Color(0x663b82f6),
    foreground: Color(0xff54f1b5),
    background: Color(0xff07111e),
    black: Color(0xff07111e),
    red: Color(0xffff6b6b),
    green: Color(0xff54f1b5),
    yellow: Color(0xffffc857),
    blue: Color(0xff63a4ff),
    magenta: Color(0xffc792ea),
    cyan: Color(0xff62d6e8),
    white: Color(0xffdceaf4),
    brightBlack: Color(0xff52677d),
    brightRed: Color(0xffff8b8b),
    brightGreen: Color(0xff7ff6c9),
    brightYellow: Color(0xffffd978),
    brightBlue: Color(0xff8dbdff),
    brightMagenta: Color(0xffd9a8f1),
    brightCyan: Color(0xff8ce4f0),
    brightWhite: Color(0xffffffff),
    searchHitBackground: Color(0xffffc857),
    searchHitBackgroundCurrent: Color(0xffff8b3d),
    searchHitForeground: Color(0xff07111e),
  );

  @override
  void dispose() {
    _terminalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: session,
          builder: (context, child) => Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xff0b1b2b),
            child: Row(
              children: [
                Icon(
                  _statusIcon(session.status),
                  size: 13,
                  color: _statusColor(session.status),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.title ?? _statusText(session),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: TerminalView(
            session.terminal,
            controller: _terminalController,
            theme: _terminalTheme,
            textStyle: const TerminalStyle(fontSize: 13, fontFamily: 'Courier'),
            padding: const EdgeInsets.all(10),
            autofocus: false,
            alwaysShowCursor: true,
            onSecondaryTapDown: (details, offset) async {
              final selection = _terminalController.selection;
              if (selection != null) {
                final text = session.terminal.buffer.getText(selection);
                _terminalController.clearSelection();
                await Clipboard.setData(ClipboardData(text: text));
                return;
              }
              final data = await Clipboard.getData('text/plain');
              if (data?.text case final text?) await _paste(text);
            },
            onKeyEvent: (node, event) {
              final isPaste =
                  event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.keyV &&
                  (HardwareKeyboard.instance.isControlPressed ||
                      HardwareKeyboard.instance.isMetaPressed);
              if (!isPaste) return KeyEventResult.ignored;
              Clipboard.getData('text/plain').then((data) {
                if (data?.text case final text?) _paste(text);
              });
              return KeyEventResult.handled;
            },
          ),
        ),
      ],
    );
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
      TerminalSessionStatus.running => const Color(0xff54f1b5),
      TerminalSessionStatus.exited => Colors.blueGrey,
      TerminalSessionStatus.failed => Colors.redAccent,
    };
  }
}
