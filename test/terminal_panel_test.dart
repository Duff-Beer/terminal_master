import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/shell_profile.dart';
import 'package:terminal_master/widgets/terminal_panel.dart';
import 'package:xterm/xterm.dart';

import 'support/fake_terminal_backend.dart';

void main() {
  testWidgets('keeps one terminal session while navigating between pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final factory = RecordingTerminalBackendFactory();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: TerminalWorkspace(
          backendFactory: factory.create,
          navigatorKey: navigatorKey,
          child: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => const _FirstPage(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Send first'));
    await tester.pumpAndSettle();

    expect(factory.backends, hasLength(1));
    expect(find.byType(TerminalPanel), findsOneWidget);
    expect(find.text('First page'), findsOneWidget);

    await tester.tap(find.text('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Second page'), findsOneWidget);
    expect(find.byType(TerminalPanel), findsOneWidget);

    await tester.tap(find.text('Send second'));
    await tester.pump();

    expect(factory.backends, hasLength(1));
    expect(factory.backends.single.writes, isEmpty);
    final input = tester.widget<TextField>(
      find.byKey(const Key('terminal-command-input')),
    );
    expect(input.controller!.text, 'echo first\necho second');

    await tester.tap(find.byKey(const Key('send-terminal-input')));
    await tester.pump();
    final writes = factory.backends.single.writes.map(utf8.decode).toList();
    expect(writes, hasLength(1));
    expect(writes.single, contains('echo first\necho second'));

    final panelController = TerminalPanelScope.of(
      tester.element(find.byType(TerminalPanel)),
    );
    final block = panelController.session.commandBlocks.single;
    factory.backends.single.emit(
      utf8.encode('tracked output\r\n${block.marker}:0\r\n'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('terminal-command-history-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('terminal-command-history')), findsOneWidget);
    expect(find.text('echo first\necho second'), findsOneWidget);
    expect(find.textContaining('Erfolgreich (Exit 0)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hide-terminal-panel')));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalPanel), findsNothing);
    expect(factory.backends.single.wasKilled, isFalse);
    expect(find.text('Second page'), findsOneWidget);
  });

  testWidgets('maximizes the panel and changes the terminal font size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final factory = RecordingTerminalBackendFactory();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: TerminalWorkspace(
          backendFactory: factory.create,
          navigatorKey: navigatorKey,
          child: const _FirstPage(),
        ),
      ),
    );
    await tester.tap(find.text('Send first'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('terminal-side-panel'))).width,
      520,
    );
    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).textStyle.fontSize,
      13,
    );

    await tester.tap(find.byKey(const Key('maximize-terminal-panel')));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('terminal-side-panel'))).width,
      1200,
    );
    expect(find.text('First page'), findsOneWidget);
    expect(factory.backends, hasLength(1));

    await tester.tap(find.byKey(const Key('terminal-zoom-in')));
    await tester.pump();
    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).textStyle.fontSize,
      14,
    );

    await tester.tap(find.byKey(const Key('terminal-zoom-reset')));
    await tester.pump();
    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).textStyle.fontSize,
      13,
    );
  });

  testWidgets('searches the scrollback and jumps back to current output', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final factory = RecordingTerminalBackendFactory();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: TerminalWorkspace(
          backendFactory: factory.create,
          navigatorKey: navigatorKey,
          child: const _FirstPage(),
        ),
      ),
    );
    await tester.tap(find.text('Send first'));
    await tester.pumpAndSettle();

    final lines = List.generate(
      80,
      (index) => index == 12 || index == 62
          ? 'line $index needle'
          : 'line $index output',
    ).join('\r\n');
    factory.backends.single.emit(utf8.encode('$lines\r\n'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('terminal-search-toggle')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('terminal-search-input')),
      'needle',
    );
    await tester.pump();

    expect(find.text('1/2'), findsOneWidget);
    final terminalView = tester.widget<TerminalView>(find.byType(TerminalView));
    expect(terminalView.controller!.highlights, hasLength(2));
    expect(
      tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('terminal-search-next')));
    await tester.pump();
    expect(find.text('2/2'), findsOneWidget);

    final scrollController = terminalView.scrollController!;
    expect(scrollController.position.maxScrollExtent, greaterThan(0));
    scrollController.jumpTo(0);
    await tester.pump();
    expect(find.byKey(const Key('terminal-scroll-to-bottom')), findsOneWidget);

    await tester.tap(find.byKey(const Key('terminal-scroll-to-bottom')));
    await tester.pump();
    expect(scrollController.offset, scrollController.position.maxScrollExtent);
    expect(find.byKey(const Key('terminal-scroll-to-bottom')), findsNothing);
  });

  testWidgets('shows TUI state and forwards reported mouse clicks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final factory = RecordingTerminalBackendFactory();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: TerminalWorkspace(
          backendFactory: factory.create,
          navigatorKey: navigatorKey,
          child: const _FirstPage(),
        ),
      ),
    );
    await tester.tap(find.text('Send first'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('terminal-true-color-indicator')),
      findsOneWidget,
    );
    factory.backends.single.emit(
      utf8.encode('\x1b]0;Interactive Tool\x07\x1b[?1049h\x1b[?1000h'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Interactive Tool'), findsWidgets);
    expect(
      find.byKey(const Key('terminal-alt-screen-indicator')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('terminal-mouse-mode-indicator')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('terminal-mouse-overlay')));
    await tester.pump(const Duration(milliseconds: 301));
    expect(
      factory.backends.single.writes.map(utf8.decode),
      contains(startsWith('\x1b[M')),
    );

    factory.backends.single.emit(
      utf8.encode('\x1b[?1000l\x1b[?1002h\x1b[?1006h'),
    );
    await tester.pump();
    final writesBeforeDrag = factory.backends.single.writes.length;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('terminal-mouse-overlay'))),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveBy(const Offset(40, 20));
    await gesture.up();
    await tester.pump();
    final dragWrites = factory.backends.single.writes
        .skip(writesBeforeDrag)
        .map(utf8.decode)
        .toList();
    expect(
      dragWrites.any((write) => write.startsWith('\x1b[<32;')),
      isTrue,
      reason: '$dragWrites',
    );

    factory.backends.single.emit(utf8.encode('\x1b[?1002l\x1b[?1049l'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('terminal-alt-screen-indicator')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('terminal-mouse-mode-indicator')),
      findsNothing,
    );
  });

  testWidgets('shows session details and provides a terminal context menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final factory = RecordingTerminalBackendFactory();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: TerminalWorkspace(
          backendFactory: factory.create,
          navigatorKey: navigatorKey,
          child: const _FirstPage(),
        ),
      ),
    );
    await tester.tap(find.text('Send first'));
    await tester.pumpAndSettle();

    factory.backends.single.emit(
      utf8.encode(
        '\x1b]7;file://localhost/tmp/project\x07'
        'https://example.com/docs',
      ),
    );
    await tester.pumpAndSettle();

    final panelController = TerminalPanelScope.of(
      tester.element(find.byType(TerminalPanel)),
    );
    expect(
      find.text('${panelController.activeProfile.name} · /tmp/project'),
      findsOneWidget,
    );

    final terminalState = tester.state<TerminalViewState>(
      find.byType(TerminalView),
    );
    final renderTerminal = terminalState.renderTerminal;
    final linkPosition = renderTerminal.localToGlobal(
      renderTerminal.getOffset(const CellOffset(8, 0)) +
          renderTerminal.cellSize.center(Offset.zero),
    );
    await tester.tapAt(
      linkPosition,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Link öffnen'), findsOneWidget);
    expect(find.text('Kopieren'), findsOneWidget);
    expect(find.text('Einfügen'), findsOneWidget);
    expect(find.text('Alles auswählen'), findsOneWidget);
    expect(find.text('Auswahl suchen'), findsOneWidget);
    expect(find.text('Ausgabe leeren'), findsOneWidget);

    await tester.tap(find.text('Alles auswählen'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TerminalView>(find.byType(TerminalView))
          .controller!
          .selection,
      isNotNull,
    );

    await tester.tapAt(
      linkPosition,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ausgabe leeren'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TerminalView>(find.byType(TerminalView))
          .terminal
          .buffer
          .getText(),
      isNot(contains('example.com')),
    );
  });

  testWidgets('keeps drafts isolated across tabs and supports split view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final factory = RecordingTerminalBackendFactory();
    final navigatorKey = GlobalKey<NavigatorState>();
    const profiles = [
      ShellProfile(
        id: 'primary',
        name: 'Primary Shell',
        executable: '/bin/primary',
        dialect: ShellDialect.posix,
      ),
      ShellProfile(
        id: 'secondary',
        name: 'Secondary Shell',
        executable: '/bin/secondary',
        dialect: ShellDialect.posix,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: TerminalWorkspace(
          backendFactory: factory.create,
          navigatorKey: navigatorKey,
          profiles: profiles,
          child: const _FirstPage(),
        ),
      ),
    );
    final controller = TerminalPanelScope.of(
      tester.element(find.byType(_FirstPage)),
    );

    await controller.insertCommand('echo primary');
    await tester.pumpAndSettle();
    final primaryId = controller.activeTab.id;
    expect(factory.backends, hasLength(1));

    await tester.tap(find.byKey(const Key('new-terminal-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Secondary Shell'));
    await tester.pumpAndSettle();
    final secondaryId = controller.activeTab.id;
    expect(factory.backends, hasLength(2));

    await controller.insertCommand('echo secondary');
    await tester.pump();
    expect(controller.commandController.text, 'echo secondary');

    await controller.selectTab(primaryId);
    await tester.pump();
    expect(controller.commandController.text, 'echo primary');
    await controller.sendPending();
    expect(
      factory.backends.first.writes.map(utf8.decode).single,
      contains('echo primary'),
    );
    expect(factory.backends.last.writes, isEmpty);

    await controller.toggleSplit();
    await tester.pump();
    expect(controller.isSplit, isTrue);
    expect(find.byType(TerminalPane).hitTestable(), findsNWidgets(2));

    controller.focusTab(secondaryId);
    await tester.pump();
    expect(controller.commandController.text, 'echo secondary');
    await controller.sendPending();
    expect(
      factory.backends.last.writes.map(utf8.decode).single,
      contains('echo secondary'),
    );

    controller.closeTab(secondaryId);
    await tester.pump();
    expect(controller.tabs, hasLength(1));
    expect(factory.backends.last.wasKilled, isTrue);
  });
}

class _FirstPage extends StatelessWidget {
  const _FirstPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('First page')),
      body: Row(
        children: [
          ElevatedButton(
            onPressed: () =>
                TerminalPanelScope.of(context).insertCommand('echo first'),
            child: const Text('Send first'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const _SecondPage()),
            ),
            child: const Text('Next page'),
          ),
        ],
      ),
    );
  }
}

class _SecondPage extends StatelessWidget {
  const _SecondPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second page')),
      body: Align(
        alignment: Alignment.topLeft,
        child: ElevatedButton(
          onPressed: () =>
              TerminalPanelScope.of(context).insertCommand('echo second'),
          child: const Text('Send second'),
        ),
      ),
    );
  }
}
