import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../services/terminal_backend.dart';
import '../services/terminal_session.dart';

class IntegratedTerminalPage extends StatefulWidget {
  final List<String> initialCommands;
  final TerminalBackendFactory backendFactory;

  const IntegratedTerminalPage({
    super.key,
    this.initialCommands = const [],
    this.backendFactory = unavailableTerminalBackendFactory,
  });

  @override
  State<IntegratedTerminalPage> createState() => _IntegratedTerminalPageState();
}

class _IntegratedTerminalPageState extends State<IntegratedTerminalPage>
    with SingleTickerProviderStateMixin {
  late final List<TerminalSession> _sessions;
  TabController? _tabController;
  bool _allowPop = false;
  bool _isClosing = false;

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
  void initState() {
    super.initState();
    final commands = widget.initialCommands.isEmpty
        ? const <String?>[null]
        : widget.initialCommands.cast<String?>();
    _sessions = [
      for (final command in commands)
        TerminalSession(
          backendFactory: widget.backendFactory,
          initialCommand: command,
        ),
    ];
    if (_sessions.length > 1) {
      _tabController = TabController(length: _sessions.length, vsync: this);
      if (Platform.isWindows) {
        _tabController!.addListener(_startCurrentWindowsTab);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Platform.isWindows && _sessions.length > 1) {
        _sessions.first.start();
      } else {
        for (final session in _sessions) {
          session.start();
        }
      }
    });
  }

  void _startCurrentWindowsTab() {
    final index = _tabController?.index;
    if (index != null) _sessions[index].start();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_startCurrentWindowsTab);
    _tabController?.dispose();
    for (final session in _sessions) {
      session.dispose();
    }
    super.dispose();
  }

  Future<void> _requestClose() async {
    if (_isClosing) return;
    _isClosing = true;
    final running = _sessions.any((session) => session.isRunning);
    var approved = true;
    if (running) {
      approved =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Terminal schließen?'),
              content: const Text(
                'Laufende Prozesse werden beendet. Unterbrechen Sie keine '
                'Datei- oder Systemoperation, solange sie noch arbeitet.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Prozesse beenden'),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!approved || !mounted) {
      _isClosing = false;
      return;
    }
    try {
      await Future.wait(_sessions.map((session) => session.stop()));
    } on Object catch (error) {
      if (!mounted) return;
      _isClosing = false;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Terminal läuft noch'),
          content: SelectableText(
            'Mindestens ein Prozess konnte nicht sicher beendet werden:\n$error',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tabController = _tabController;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Integriertes Terminal'),
          bottom: tabController == null
              ? null
              : TabBar(
                  controller: tabController,
                  tabs: [
                    for (var i = 0; i < _sessions.length; i++)
                      Tab(text: 'Terminal ${i + 1}'),
                  ],
                ),
        ),
        body: tabController == null
            ? _TerminalPane(session: _sessions.single)
            : TabBarView(
                controller: tabController,
                children: [
                  for (final session in _sessions)
                    _TerminalPane(session: session),
                ],
              ),
      ),
    );
  }
}

class _TerminalPane extends StatefulWidget {
  final TerminalSession session;

  const _TerminalPane({required this.session});

  @override
  State<_TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends State<_TerminalPane> {
  final _controller = TerminalController();

  TerminalSession get session => widget.session;

  @override
  void dispose() {
    _controller.dispose();
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
            color: const Color(0xff10263a),
            child: Row(
              children: [
                Icon(
                  _statusIcon(session.status),
                  size: 14,
                  color: _statusColor(session.status),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.title ?? _statusText(session),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: TerminalView(
            session.terminal,
            controller: _controller,
            theme: _IntegratedTerminalPageState._terminalTheme,
            textStyle: const TerminalStyle(fontSize: 14, fontFamily: 'Courier'),
            padding: const EdgeInsets.all(12),
            autofocus: true,
            alwaysShowCursor: true,
            onSecondaryTapDown: (details, offset) async {
              final selection = _controller.selection;
              if (selection != null) {
                final text = session.terminal.buffer.getText(selection);
                _controller.clearSelection();
                await Clipboard.setData(ClipboardData(text: text));
                return;
              }
              final data = await Clipboard.getData('text/plain');
              if (data?.text case final text?) {
                await _paste(text);
              }
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
    final isMultiline = text.contains('\n') || text.contains('\r');
    if (isMultiline) {
      final approved =
          await showDialog<bool>(
            context: context,
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
