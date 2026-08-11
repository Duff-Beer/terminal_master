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

  testWidgets('keeps split terminal sessions isolated across tabs', (
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
    final primaryTabId = controller.activeTab.id;
    expect(factory.backends, hasLength(1));

    await tester.tap(find.byKey(const Key('new-terminal-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Secondary Shell'));
    await tester.pumpAndSettle();
    final secondaryTabId = controller.activeTab.id;
    expect(factory.backends, hasLength(2));

    await controller.insertCommand('echo secondary');
    await tester.pump();
    expect(controller.commandController.text, 'echo secondary');

    await controller.selectTab(primaryTabId);
    await tester.pump();
    expect(controller.commandController.text, 'echo primary');
    await controller.sendPending();
    expect(
      factory.backends.first.writes.map(utf8.decode).single,
      contains('echo primary'),
    );
    expect(factory.backends.last.writes, isEmpty);

    expect(find.byKey(const Key('split-terminal-panel')), findsNothing);
    final commandBlocks = find.byKey(
      const Key('terminal-command-history-toggle'),
    );
    final verticalSplit = find.byKey(const Key('split-terminal-vertical'));
    final horizontalSplit = find.byKey(const Key('split-terminal-horizontal'));
    expect(
      tester.getCenter(commandBlocks).dx,
      lessThan(tester.getCenter(verticalSplit).dx),
    );
    expect(
      tester.getCenter(verticalSplit).dx,
      lessThan(tester.getCenter(horizontalSplit).dx),
    );

    await tester.tap(verticalSplit);
    await tester.pumpAndSettle();
    expect(controller.isSplit, isTrue);
    expect(controller.hasSplit(TerminalSplitOrientation.vertical), isTrue);
    expect(controller.hasSplit(TerminalSplitOrientation.horizontal), isFalse);
    expect(controller.tabs, hasLength(2));
    expect(controller.activeTab.panes, hasLength(2));
    expect(factory.backends, hasLength(3));
    expect(find.byType(TerminalPane).hitTestable(), findsNWidgets(2));
    var visiblePanes = find.byType(TerminalPane).hitTestable();
    var firstPanePosition = tester.getTopLeft(visiblePanes.at(0));
    var secondPanePosition = tester.getTopLeft(visiblePanes.at(1));
    expect(firstPanePosition.dy, closeTo(secondPanePosition.dy, 0.1));
    expect(firstPanePosition.dx, lessThan(secondPanePosition.dx));

    await tester.tap(find.byKey(const Key('split-terminal-horizontal')));
    await tester.pumpAndSettle();
    expect(controller.hasSplit(TerminalSplitOrientation.vertical), isTrue);
    expect(controller.hasSplit(TerminalSplitOrientation.horizontal), isTrue);
    expect(controller.activeTab.panes, hasLength(4));
    expect(factory.backends, hasLength(5));
    visiblePanes = find.byType(TerminalPane).hitTestable();
    expect(visiblePanes, findsNWidgets(4));
    final panePositions = List.generate(
      4,
      (index) => tester.getTopLeft(visiblePanes.at(index)),
    );
    expect(panePositions[0].dy, closeTo(panePositions[1].dy, 0.1));
    expect(panePositions[0].dx, lessThan(panePositions[1].dx));
    expect(panePositions[0].dx, closeTo(panePositions[2].dx, 0.1));
    expect(panePositions[0].dy, lessThan(panePositions[2].dy));
    expect(panePositions[2].dy, closeTo(panePositions[3].dy, 0.1));
    expect(panePositions[2].dx, lessThan(panePositions[3].dx));

    final primarySplitPaneId = controller.activeTab
        .paneAt(row: 1, column: 1)!
        .id;
    controller.focusPane(primarySplitPaneId);
    await tester.pump();
    expect(controller.commandController.text, isEmpty);
    await controller.insertCommand('echo primary split');
    await controller.sendPending();
    expect(
      factory.backends[4].writes.map(utf8.decode).single,
      contains('echo primary split'),
    );

    factory.backends[0].emit(utf8.encode('PRIMARY_TOP_LEFT\r\n'));
    factory.backends[2].emit(utf8.encode('PRIMARY_TOP_RIGHT\r\n'));
    factory.backends[3].emit(utf8.encode('PRIMARY_BOTTOM_LEFT\r\n'));
    factory.backends[4].emit(utf8.encode('PRIMARY_BOTTOM_RIGHT\r\n'));
    await tester.pump();
    var visibleOutput = find
        .byType(TerminalView)
        .hitTestable()
        .evaluate()
        .map(
          (element) =>
              (element.widget as TerminalView).terminal.buffer.getText(),
        )
        .toList();
    expect(visibleOutput, hasLength(4));
    expect(
      visibleOutput.any((output) => output.contains('PRIMARY_TOP_LEFT')),
      isTrue,
    );
    expect(
      visibleOutput.any((output) => output.contains('PRIMARY_TOP_RIGHT')),
      isTrue,
    );
    expect(
      visibleOutput.any((output) => output.contains('PRIMARY_BOTTOM_LEFT')),
      isTrue,
    );
    expect(
      visibleOutput.any((output) => output.contains('PRIMARY_BOTTOM_RIGHT')),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('split-terminal-vertical')));
    await tester.pumpAndSettle();
    expect(controller.hasSplit(TerminalSplitOrientation.vertical), isFalse);
    expect(controller.hasSplit(TerminalSplitOrientation.horizontal), isTrue);
    expect(find.byType(TerminalPane).hitTestable(), findsNWidgets(2));
    expect(factory.backends, hasLength(5));
    await tester.tap(find.byKey(const Key('split-terminal-vertical')));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalPane).hitTestable(), findsNWidgets(4));
    expect(factory.backends, hasLength(5));

    await controller.selectTab(secondaryTabId);
    await controller.toggleSplit(TerminalSplitOrientation.horizontal);
    await tester.pump();
    expect(controller.isSplit, isTrue);
    expect(controller.activeTab.panes, hasLength(2));
    expect(factory.backends, hasLength(6));

    factory.backends[1].emit(utf8.encode('SECONDARY_MAIN\r\n'));
    factory.backends[5].emit(utf8.encode('SECONDARY_SPLIT\r\n'));
    await tester.pump();
    visibleOutput = find
        .byType(TerminalView)
        .hitTestable()
        .evaluate()
        .map(
          (element) =>
              (element.widget as TerminalView).terminal.buffer.getText(),
        )
        .toList();
    expect(visibleOutput, hasLength(2));
    expect(
      visibleOutput.any((output) => output.contains('SECONDARY_MAIN')),
      isTrue,
    );
    expect(
      visibleOutput.any((output) => output.contains('SECONDARY_SPLIT')),
      isTrue,
    );
    expect(
      visibleOutput.every((output) => !output.contains('PRIMARY_')),
      isTrue,
    );

    await controller.selectTab(primaryTabId);
    await tester.pump();
    visibleOutput = find
        .byType(TerminalView)
        .hitTestable()
        .evaluate()
        .map(
          (element) =>
              (element.widget as TerminalView).terminal.buffer.getText(),
        )
        .toList();
    expect(
      visibleOutput.every((output) => !output.contains('SECONDARY_')),
      isTrue,
    );

    controller.closeTab(secondaryTabId);
    await tester.pump();
    expect(controller.tabs, hasLength(1));
    expect(factory.backends[1].wasKilled, isTrue);
    expect(factory.backends[5].wasKilled, isTrue);
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
