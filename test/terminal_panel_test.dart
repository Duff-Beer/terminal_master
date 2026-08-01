import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(writes.single, startsWith('echo first\necho second'));

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
