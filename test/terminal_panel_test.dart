import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';
import 'package:terminal_master/models/saved_terminal_tab.dart';
import 'package:terminal_master/models/shell_profile.dart';
import 'package:terminal_master/services/saved_terminal_tab_store.dart';
import 'package:terminal_master/services/terminal_session.dart';
import 'package:terminal_master/widgets/terminal_panel.dart';
import 'package:xterm/xterm.dart';

import 'support/fake_terminal_backend.dart';

void main() {
  test('splits, closes, and restores an arbitrary nested layout', () async {
    final controller = TerminalPanelController(
      backendFactory: RecordingTerminalBackendFactory().create,
      navigatorKey: GlobalKey<NavigatorState>(),
      profiles: const [
        ShellProfile(
          id: 'primary',
          name: 'Primary Shell',
          executable: '/bin/primary',
          dialect: ShellDialect.posix,
        ),
      ],
      savedTabStore: MemorySavedTerminalTabStore(),
    );
    addTearDown(controller.dispose);

    for (var index = 0; index < 4; index++) {
      await controller.toggleSplit(
        index.isEven
            ? TerminalSplitOrientation.vertical
            : TerminalSplitOrientation.horizontal,
      );
    }
    expect(controller.activeTab.panes, hasLength(5));
    expect(
      controller.activeTab.layout.paneIds.toSet(),
      controller.activeTab.panes.map((pane) => pane.id).toSet(),
    );

    final snapshot = await controller.saveActiveTab('Nested Layout');
    expect(snapshot.layout, isNotNull);
    expect(snapshot.panes, hasLength(5));
    final restored = await controller.openSavedTab(snapshot.id);
    expect(restored.panes, hasLength(5));
    expect(
      restored.layout.paneIds.toSet(),
      restored.panes.map((pane) => pane.id).toSet(),
    );
    final rootSplit = restored.layout as TerminalLayoutSplit;
    controller.resizeSplit(
      rootSplit.first.paneIds.first,
      rootSplit.second.paneIds.first,
      0.1,
    );
    expect((restored.layout as TerminalLayoutSplit).ratio, closeTo(0.6, 0.001));
    final resizedSnapshot = await controller.saveActiveTab('Nested Layout');
    expect(
      (resizedSnapshot.layout['ratio'] as num).toDouble(),
      closeTo(0.6, 0.001),
    );

    final removedPaneId = restored.activePane.id;
    expect(await controller.closePane(removedPaneId), isTrue);
    expect(restored.panes, hasLength(4));
    expect(restored.layout.paneIds, hasLength(4));
    while (restored.panes.length > 1) {
      await controller.closePane(restored.panes.last.id);
    }
    final lastPaneId = restored.panes.single.id;
    expect(await controller.closePane(lastPaneId), isTrue);
    expect(restored.panes, hasLength(1));
    expect(restored.panes.single.id, isNot(lastPaneId));
    expect(restored.layout.paneIds.single, restored.panes.single.id);
  });

  testWidgets('deletes a saved state only after confirmation', (tester) async {
    final createdAt = DateTime.utc(2026, 1, 1);
    final savedState = SavedTerminalTab(
      id: 'saved-to-delete',
      name: 'Temporary Layout',
      createdAt: createdAt,
      updatedAt: createdAt,
      panes: const [SavedTerminalPane(profileId: 'primary')],
      layout: const {'pane': 0},
      focusedPaneIndex: 0,
    );
    final store = MemorySavedTerminalTabStore([savedState]);
    final factory = RecordingTerminalBackendFactory();
    final navigatorKey = GlobalKey<NavigatorState>();
    const profiles = [
      ShellProfile(
        id: 'primary',
        name: 'Primary Shell',
        executable: '/bin/primary',
        dialect: ShellDialect.posix,
      ),
    ];

    await tester.pumpWidget(
      localizedApp(
        navigatorKey: navigatorKey,
        home: TerminalWorkspace(
          backendFactory: factory.create,
          navigatorKey: navigatorKey,
          profiles: profiles,
          savedTabStore: store,
          child: const _FirstPage(),
        ),
      ),
    );
    final controller = TerminalPanelScope.of(
      tester.element(find.byType(_FirstPage)),
    );
    await tester.pumpAndSettle();
    expect(controller.savedTabs, hasLength(1));
    expect(find.byKey(const Key('terminal-bottom-toolbar')), findsNothing);
    await tester.tap(find.byKey(const Key('toggle-command-bar-pinned')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('terminal-bottom-toolbar')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('terminal-command-input')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.tap(find.byKey(const Key('toggle-command-bar-pinned')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('terminal-bottom-toolbar')), findsNothing);
    await tester.tap(find.byKey(const Key('toggle-command-bar-pinned')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('terminal-command-input')),
      'echo draft',
    );
    await tester.tap(find.byKey(const Key('toggle-command-bar-pinned')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('terminal-bottom-toolbar')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('terminal-command-input')))
          .controller!
          .text,
      'echo draft',
    );
    expect(
      tester.getCenter(find.byKey(const Key('terminal-search-toggle'))).dx,
      lessThan(
        tester.getCenter(find.byKey(const Key('open-saved-terminal-tab'))).dx,
      ),
    );

    await tester.tap(find.byKey(const Key('open-saved-terminal-tab')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('delete-saved-terminal-tab-saved-to-delete')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gespeicherten Zustand löschen?'), findsOneWidget);
    expect(controller.savedTabs, hasLength(1));

    await tester.tap(
      find.byKey(const Key('confirm-delete-saved-terminal-tab')),
    );
    await tester.pumpAndSettle();
    expect(controller.savedTabs, isEmpty);
    expect(await store.load(), isEmpty);
    expect(controller.tabs, hasLength(1));
  });

  test('serializes tab saves without losing snapshots', () async {
    final store = MemorySavedTerminalTabStore();
    const profile = ShellProfile(
      id: 'primary',
      name: 'Primary Shell',
      executable: '/bin/primary',
      dialect: ShellDialect.posix,
    );
    final controller = TerminalPanelController(
      backendFactory: RecordingTerminalBackendFactory().create,
      navigatorKey: GlobalKey<NavigatorState>(),
      profiles: const [profile],
      savedTabStore: store,
    );
    addTearDown(controller.dispose);
    final firstSave = controller.saveActiveTab('First Snapshot');
    await controller.createTab(profile);
    final secondSave = controller.saveActiveTab('Second Snapshot');

    await Future.wait([firstSave, secondSave]);
    final snapshots = await store.load();

    expect(snapshots.map((snapshot) => snapshot.name).toSet(), {
      'First Snapshot',
      'Second Snapshot',
    });
  });

  test('rejects updates from a stale opened snapshot copy', () async {
    final store = MemorySavedTerminalTabStore();
    const profile = ShellProfile(
      id: 'primary',
      name: 'Primary Shell',
      executable: '/bin/primary',
      dialect: ShellDialect.posix,
    );
    final controller = TerminalPanelController(
      backendFactory: RecordingTerminalBackendFactory().create,
      navigatorKey: GlobalKey<NavigatorState>(),
      profiles: const [profile],
      savedTabStore: store,
    );
    addTearDown(controller.dispose);
    final snapshot = await controller.saveActiveTab('Shared Snapshot');
    await controller.openSavedTab(snapshot.id);
    final firstCopyId = controller.activeTab.id;
    await controller.openSavedTab(snapshot.id);
    final staleCopyId = controller.activeTab.id;

    await controller.selectTab(firstCopyId);
    await controller.saveActiveTab('Updated Snapshot');
    await controller.selectTab(staleCopyId);

    await expectLater(
      controller.saveActiveTab('Stale Update'),
      throwsA(
        isA<TerminalTabException>().having(
          (error) => error.failure,
          'failure',
          TerminalTabFailure.savedTabChangedMeanwhile,
        ),
      ),
    );
    expect((await store.load()).single.name, 'Updated Snapshot');
  });

  test('gracefully stops a running session before restarting it', () async {
    final factory = RecordingTerminalBackendFactory();
    final controller = TerminalPanelController(
      backendFactory: factory.create,
      navigatorKey: GlobalKey<NavigatorState>(),
      profiles: const [
        ShellProfile(
          id: 'primary',
          name: 'Primary Shell',
          executable: '/bin/primary',
          dialect: ShellDialect.posix,
        ),
      ],
      savedTabStore: MemorySavedTerminalTabStore(),
    );
    addTearDown(controller.dispose);
    await controller.attach();
    controller.commandController.text = 'echo pending';
    final paneId = controller.activePane.id;

    await controller.restartPane(paneId);

    expect(factory.backends, hasLength(2));
    expect(factory.backends.first.wasKilled, isFalse);
    expect(
      factory.backends.first.writes.map(utf8.decode),
      containsAllInOrder(['\x03', 'exit\n']),
    );
    expect(controller.commandController.text, 'echo pending');
    expect(controller.session.status, TerminalSessionStatus.running);
  });

  test('persists a custom tab name when saving and reopening', () async {
    final store = MemorySavedTerminalTabStore();
    final controller = TerminalPanelController(
      backendFactory: RecordingTerminalBackendFactory().create,
      navigatorKey: GlobalKey<NavigatorState>(),
      profiles: const [
        ShellProfile(
          id: 'primary',
          name: 'Primary Shell',
          executable: '/bin/primary',
          dialect: ShellDialect.posix,
        ),
      ],
      savedTabStore: store,
    );
    addTearDown(controller.dispose);

    controller.renameTab(controller.activeTab.id, '  Build Server  ');
    final snapshot = await controller.saveActiveTab();
    final reopened = await controller.openSavedTab(snapshot.id);

    expect(snapshot.name, 'Build Server');
    expect((await store.load()).single.name, 'Build Server');
    expect(reopened.customName, 'Build Server');
    expect(reopened.displayName, 'Build Server');
  });

  testWidgets('does not overwrite snapshots after a load failure', (
    tester,
  ) async {
    final store = _FailingSavedTerminalTabStore();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      localizedApp(
        navigatorKey: navigatorKey,
        home: TerminalWorkspace(
          backendFactory: RecordingTerminalBackendFactory().create,
          navigatorKey: navigatorKey,
          savedTabStore: store,
          child: const _FirstPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controller = TerminalPanelScope.of(
      tester.element(find.byType(_FirstPage)),
    );

    expect(controller.savedTabsError, isNotNull);
    await expectLater(
      controller.saveActiveTab('Must not overwrite'),
      throwsA(
        isA<TerminalTabException>().having(
          (error) => error.failure,
          'failure',
          TerminalTabFailure.savedTabsUnreadable,
        ),
      ),
    );
    expect(store.saveCalls, 0);
  });

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
      localizedApp(
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
    await tester.tap(find.byKey(const Key('configuration-panel-toggle')));
    await tester.pumpAndSettle();

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
    await tester.tap(find.byKey(const Key('configuration-panel-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Second page'), findsOneWidget);

    expect(factory.backends, hasLength(1));
    expect(factory.backends.single.writes, isEmpty);
    final input = tester.widget<TextField>(
      find.byKey(const Key('terminal-command-input')),
    );
    expect(input.controller!.text, 'echo first\necho second');

    expect(
      find.descendant(
        of: find.byKey(const Key('send-terminal-input')),
        matching: find.byIcon(Icons.send_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('send-terminal-input')));
    await tester.pump();
    expect(find.text('Second page'), findsOneWidget);
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
    expect(find.text('Second page'), findsOneWidget);
    expect(find.byKey(const Key('terminal-command-history')), findsOneWidget);
    expect(find.text('echo first\necho second'), findsOneWidget);
    expect(find.textContaining('Erfolgreich (Exit 0)'), findsOneWidget);

    expect(find.byType(TerminalPanel), findsOneWidget);
    expect(
      find.byKey(const Key('configuration-panel')).hitTestable(),
      findsNothing,
    );
    expect(factory.backends.single.wasKilled, isFalse);
    await tester.tap(find.byKey(const Key('configuration-panel-toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('configuration-panel')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Second page'), findsOneWidget);
  });

  testWidgets(
    'keeps terminal size while opening config and changes font size',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final factory = RecordingTerminalBackendFactory();
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        localizedApp(
          navigatorKey: navigatorKey,
          home: TerminalWorkspace(
            backendFactory: factory.create,
            navigatorKey: navigatorKey,
            child: const _FirstPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('terminal-tab-bar'))).dy,
        0,
      );
      expect(
        tester.getSize(find.byKey(const Key('terminal-workspace'))).width,
        1152,
      );
      expect(
        tester
            .widget<TerminalView>(find.byType(TerminalView))
            .textStyle
            .fontSize,
        13,
      );
      expect(find.byKey(const Key('stop-terminal-session')), findsNothing);
      final controller = TerminalPanelScope.of(
        tester.element(find.byType(TerminalPanel)),
      );
      final activeTabFinder = find.byKey(
        Key('terminal-tab-${controller.activeTab.id}'),
      );
      final addTabFinder = find.byKey(const Key('new-terminal-tab'));
      final openSavedTabFinder = find.byKey(
        const Key('open-saved-terminal-tab'),
      );
      expect(
        tester.getTopRight(activeTabFinder).dx,
        lessThanOrEqualTo(tester.getTopLeft(addTabFinder).dx),
      );
      expect(
        tester.getTopRight(addTabFinder).dx,
        lessThanOrEqualTo(tester.getTopLeft(openSavedTabFinder).dx),
      );
      await tester.tap(activeTabFinder, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text('Sitzung neu starten'), findsOneWidget);
      expect(find.text('Tab umbenennen'), findsOneWidget);
      expect(find.text('Tab speichern'), findsOneWidget);
      expect(find.text('Tab schließen'), findsNothing);
      await tester.tap(find.text('Sitzung neu starten'));
      await tester.pumpAndSettle();
      expect(find.text('Terminal-Sitzung neu starten?'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(Key('terminal-tab-${controller.activeTab.id}')),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tab umbenennen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('terminal-tab-name')),
        'Build Server',
      );
      await tester.tap(find.byKey(const Key('confirm-rename-terminal-tab')));
      await tester.pumpAndSettle();
      expect(find.text('Build Server'), findsOneWidget);
      expect(controller.activeTab.customName, 'Build Server');
      expect(find.byKey(const Key('save-terminal-tab')), findsNothing);

      await tester.tap(find.byKey(const Key('configuration-panel-toggle')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('terminal-workspace'))).width,
        1152,
      );
      expect(find.text('First page').hitTestable(), findsOneWidget);
      expect(factory.backends, hasLength(1));
      await tester.tap(find.byKey(const Key('configuration-panel-toggle')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('terminal-zoom-in')));
      await tester.pump();
      expect(
        tester
            .widget<TerminalView>(find.byType(TerminalView))
            .textStyle
            .fontSize,
        14,
      );

      await tester.tap(find.byKey(const Key('terminal-zoom-reset')));
      await tester.pump();
      expect(
        tester
            .widget<TerminalView>(find.byType(TerminalView))
            .textStyle
            .fontSize,
        13,
      );

      tester.view.physicalSize = const Size(500, 800);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('terminal-search-toggle')), findsOneWidget);
      expect(find.byKey(const Key('stop-terminal-session')), findsNothing);
      expect(find.byKey(const Key('terminal-more-actions')), findsNothing);
      await tester.tap(find.byKey(const Key('toggle-command-bar-pinned')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('terminal-bottom-toolbar')), findsOneWidget);
      expect(find.byKey(const Key('terminal-more-actions')), findsOneWidget);
      await tester.tap(find.byKey(const Key('terminal-more-actions')));
      await tester.pumpAndSettle();
      expect(find.text('Sitzung neu starten'), findsOneWidget);
    },
  );

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
      localizedApp(
        navigatorKey: navigatorKey,
        home: TerminalWorkspace(
          backendFactory: factory.create,
          navigatorKey: navigatorKey,
          child: const _FirstPage(),
        ),
      ),
    );
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
      localizedApp(
        navigatorKey: navigatorKey,
        home: TerminalWorkspace(
          backendFactory: factory.create,
          navigatorKey: navigatorKey,
          child: const _FirstPage(),
        ),
      ),
    );
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
      localizedApp(
        navigatorKey: navigatorKey,
        home: TerminalWorkspace(
          backendFactory: factory.create,
          navigatorKey: navigatorKey,
          child: const _FirstPage(),
        ),
      ),
    );
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

  testWidgets('opens a saved grid and directly replays its command', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final factory = RecordingTerminalBackendFactory();
    final navigatorKey = GlobalKey<NavigatorState>();
    final executedAt = DateTime.utc(2026, 8, 11, 18);
    final savedCommand = SavedTerminalCommand(
      command: 'echo restored',
      executedAt: executedAt,
      exitCode: 0,
    );
    final topLeftCommand = SavedTerminalCommand(
      command: 'echo top left',
      executedAt: executedAt.subtract(const Duration(minutes: 1)),
      exitCode: 0,
    );
    final store = MemorySavedTerminalTabStore([
      SavedTerminalTab(
        id: 'saved-grid',
        name: 'Saved Grid',
        createdAt: executedAt,
        updatedAt: executedAt,
        focusedPaneIndex: 3,
        layout: {
          'orientation': 'horizontal',
          'ratio': 0.5,
          'first': {
            'orientation': 'vertical',
            'ratio': 0.5,
            'first': {'pane': 0},
            'second': {'pane': 1},
          },
          'second': {
            'orientation': 'vertical',
            'ratio': 0.5,
            'first': {'pane': 2},
            'second': {'pane': 3},
          },
        },
        panes: [
          SavedTerminalPane(profileId: 'primary', commands: [topLeftCommand]),
          const SavedTerminalPane(profileId: 'primary'),
          const SavedTerminalPane(profileId: 'primary'),
          SavedTerminalPane(
            profileId: 'primary',
            workingDirectory: '/restored',
            draft: 'echo draft',
            commands: [savedCommand],
          ),
        ],
      ),
    ]);
    const profiles = [
      ShellProfile(
        id: 'primary',
        name: 'Primary Shell',
        executable: '/bin/primary',
        dialect: ShellDialect.posix,
      ),
    ];

    await tester.pumpWidget(
      localizedApp(
        navigatorKey: navigatorKey,
        home: TerminalWorkspace(
          backendFactory: factory.create,
          navigatorKey: navigatorKey,
          profiles: profiles,
          savedTabStore: store,
          child: const _FirstPage(),
        ),
      ),
    );
    final controller = TerminalPanelScope.of(
      tester.element(find.byType(_FirstPage)),
    );
    await tester.pumpAndSettle();
    expect(factory.backends, hasLength(1));

    await tester.tap(find.byKey(const Key('open-saved-terminal-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Grid'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('execute-saved-commands-on-open')),
          )
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('confirm-open-saved-terminal-tab')));
    await tester.pumpAndSettle();

    expect(controller.activeTab.snapshotName, 'Saved Grid');
    expect(controller.activeTab.visiblePanes, hasLength(4));
    expect(controller.commandController.text, 'echo draft');
    expect(factory.backends, hasLength(5));
    expect(factory.backends.last.writes, isEmpty);
    expect(factory.options.last.workingDirectory, '/restored');
    expect(find.byType(TerminalPane).hitTestable(), findsNWidgets(4));

    await tester.tap(find.byKey(const Key('terminal-command-history-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Gespeicherte Befehle'), findsOneWidget);
    expect(find.text('echo restored'), findsOneWidget);

    final commandKeySuffix =
        '${executedAt.microsecondsSinceEpoch}-'
        '${savedCommand.command.hashCode}';
    await tester.tap(
      find.byKey(Key('saved-terminal-command-menu-$commandKeySuffix')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();
    expect(controller.commandController.text, 'echo restored');

    await tester.tap(
      find.byKey(Key('run-saved-terminal-command-$commandKeySuffix')),
    );
    await tester.pump();
    expect(
      factory.backends.last.writes.map(utf8.decode).single,
      contains('echo restored'),
    );
    expect(controller.session.commandBlocks.single.command, 'echo restored');

    await tester.tap(
      find.byKey(Key('terminal-tab-${controller.activeTab.id}')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gespeicherten Tab aktualisieren'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('saved-terminal-tab-name')),
      'Updated Grid',
    );
    await tester.tap(find.byKey(const Key('confirm-save-terminal-tab')));
    await tester.pumpAndSettle();
    final updatedSnapshots = await store.load();
    expect(updatedSnapshots.single.name, 'Updated Grid');
    expect(updatedSnapshots.single.panes, hasLength(4));
    expect(
      updatedSnapshots.single.panes.last.commands.single.command,
      'echo restored',
    );

    await tester.tap(find.byKey(const Key('open-saved-terminal-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Updated Grid').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('execute-saved-commands-on-open')));
    await tester.tap(find.byKey(const Key('confirm-open-saved-terminal-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-command-execution')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-command-execution')));
    await tester.pumpAndSettle();

    expect(factory.backends, hasLength(9));
    expect(
      factory.backends[5].writes.map(utf8.decode).single,
      contains('echo top left'),
    );
    expect(
      factory.backends.last.writes.map(utf8.decode).single,
      contains('echo restored'),
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
      localizedApp(
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

    controller.setDefaultProfile('secondary');
    await tester.tap(find.byKey(const Key('new-terminal-tab')));
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
    expect(find.byKey(const Key('maximize-terminal-pane')), findsNothing);
    final commandBlocks = find.byKey(
      const Key('terminal-command-history-toggle'),
    );
    final verticalSplit = find.byKey(const Key('split-terminal-vertical'));
    final horizontalSplit = find.byKey(const Key('split-terminal-horizontal'));
    final sessionDetails = find.byKey(const Key('terminal-session-details'));
    expect(
      tester.getRect(sessionDetails).right,
      lessThan(tester.getRect(verticalSplit).left),
    );
    expect(
      tester.getCenter(verticalSplit).dx,
      lessThan(tester.getCenter(horizontalSplit).dx),
    );
    expect(
      tester.getCenter(horizontalSplit).dx,
      lessThan(tester.getCenter(commandBlocks).dx),
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

    final verticalLayout = controller.activeTab.layout as TerminalLayoutSplit;
    final firstPaneId = verticalLayout.first.paneIds.first;
    final secondPaneId = verticalLayout.second.paneIds.first;
    final divider = find.byKey(
      Key('terminal-split-divider-$firstPaneId-$secondPaneId'),
    );
    expect(tester.getSize(divider).height, greaterThan(0));
    final verticalCursorRegion = find.byKey(
      Key('terminal-split-divider-cursor-$firstPaneId-$secondPaneId'),
    );
    expect(
      tester.widget<MouseRegion>(verticalCursorRegion).cursor,
      SystemMouseCursors.resizeLeftRight,
    );
    final firstPane = find.byKey(Key('terminal-pane-position-$firstPaneId'));
    final secondPane = find.byKey(Key('terminal-pane-position-$secondPaneId'));
    final initialFirstPaneWidth = tester.getSize(firstPane).width;
    final initialSecondPaneWidth = tester.getSize(secondPane).width;
    await tester.drag(divider, const Offset(64, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(firstPane).width, greaterThan(initialFirstPaneWidth));
    expect(tester.getSize(secondPane).width, lessThan(initialSecondPaneWidth));

    await tester.tap(find.byKey(const Key('split-terminal-horizontal')));
    await tester.pumpAndSettle();
    final rootLayout = controller.activeTab.layout as TerminalLayoutSplit;
    final nestedLayout = rootLayout.second as TerminalLayoutSplit;
    final horizontalCursorRegion = find.byKey(
      Key(
        'terminal-split-divider-cursor-${nestedLayout.first.paneIds.first}-${nestedLayout.second.paneIds.first}',
      ),
    );
    expect(
      tester.widget<MouseRegion>(horizontalCursorRegion).cursor,
      SystemMouseCursors.resizeUpDown,
    );
    expect(controller.hasSplit(TerminalSplitOrientation.vertical), isTrue);
    expect(controller.hasSplit(TerminalSplitOrientation.horizontal), isTrue);
    expect(controller.activeTab.panes, hasLength(3));
    expect(factory.backends, hasLength(4));
    visiblePanes = find.byType(TerminalPane).hitTestable();
    expect(visiblePanes, findsNWidgets(3));
    final panePositions = List.generate(
      3,
      (index) => tester.getTopLeft(visiblePanes.at(index)),
    );
    expect(panePositions[0].dx, lessThan(panePositions[1].dx));
    expect(panePositions[1].dx, closeTo(panePositions[2].dx, 0.1));
    expect(panePositions[1].dy, lessThan(panePositions[2].dy));

    final primarySplitPaneId = controller.activePane.id;
    controller.focusPane(primarySplitPaneId);
    await tester.pump();
    expect(controller.commandController.text, isEmpty);
    await controller.insertCommand('echo primary split');
    await controller.sendPending();
    expect(
      factory.backends.last.writes.map(utf8.decode).single,
      contains('echo primary split'),
    );

    final panePosition = find.byKey(
      Key('terminal-pane-position-$primarySplitPaneId'),
    );
    final splitPaneSize = tester.getSize(panePosition);
    final maximizePane = find.byKey(const Key('maximize-terminal-pane'));
    expect(maximizePane, findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('split-terminal-horizontal'))).dx,
      lessThan(tester.getCenter(maximizePane).dx),
    );
    await tester.tap(maximizePane);
    await tester.pumpAndSettle();
    expect(controller.isPaneMaximized(primarySplitPaneId), isTrue);
    expect(find.byType(TerminalPane).hitTestable(), findsOneWidget);
    final maximizedPaneSize = tester.getSize(panePosition);
    expect(maximizedPaneSize.width, greaterThan(splitPaneSize.width));
    expect(maximizedPaneSize.height, greaterThan(splitPaneSize.height));
    expect(factory.backends, hasLength(4));

    factory.backends[0].emit(utf8.encode('PRIMARY_LEFT\r\n'));
    factory.backends[2].emit(utf8.encode('PRIMARY_RIGHT_TOP\r\n'));
    factory.backends[3].emit(utf8.encode('PRIMARY_RIGHT_BOTTOM\r\n'));
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
    expect(visibleOutput, hasLength(1));
    expect(visibleOutput.single, contains('PRIMARY_RIGHT_BOTTOM'));

    await tester.tap(find.byKey(const Key('maximize-terminal-pane')));
    await tester.pumpAndSettle();
    expect(controller.maximizedPaneId, isNull);
    expect(find.byType(TerminalPane).hitTestable(), findsNWidgets(3));
    visibleOutput = find
        .byType(TerminalView)
        .hitTestable()
        .evaluate()
        .map(
          (element) =>
              (element.widget as TerminalView).terminal.buffer.getText(),
        )
        .toList();
    expect(visibleOutput, hasLength(3));
    expect(
      visibleOutput.any((output) => output.contains('PRIMARY_LEFT')),
      isTrue,
    );
    expect(
      visibleOutput.any((output) => output.contains('PRIMARY_RIGHT_TOP')),
      isTrue,
    );
    expect(
      visibleOutput.any((output) => output.contains('PRIMARY_RIGHT_BOTTOM')),
      isTrue,
    );

    final closePaneOperation = controller.closePane(primarySplitPaneId);
    await tester.pump(const Duration(milliseconds: 100));
    expect(await closePaneOperation, isTrue);
    await tester.pumpAndSettle();
    expect(controller.activeTab.panes, hasLength(2));
    expect(find.byType(TerminalPane).hitTestable(), findsNWidgets(2));
    expect(factory.backends, hasLength(4));

    await controller.selectTab(secondaryTabId);
    await controller.toggleSplit(TerminalSplitOrientation.horizontal);
    await tester.pump();
    expect(controller.isSplit, isTrue);
    expect(controller.activeTab.panes, hasLength(2));
    expect(factory.backends, hasLength(5));

    factory.backends[1].emit(utf8.encode('SECONDARY_MAIN\r\n'));
    factory.backends.last.emit(utf8.encode('SECONDARY_SPLIT\r\n'));
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

    final closeOperation = controller.closeTab(secondaryTabId);
    await tester.pump(const Duration(milliseconds: 100));
    await closeOperation;
    await tester.pump();
    expect(controller.tabs, hasLength(1));
    expect(factory.backends[1].wasKilled, isFalse);
    expect(factory.backends.last.wasKilled, isFalse);
    expect(
      factory.backends[1].writes.map(utf8.decode),
      containsAllInOrder(['\x03', 'exit\n']),
    );
    expect(
      factory.backends.last.writes.map(utf8.decode),
      containsAllInOrder(['\x03', 'exit\n']),
    );
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

class _FailingSavedTerminalTabStore implements SavedTerminalTabStore {
  var saveCalls = 0;

  @override
  Future<List<SavedTerminalTab>> load() async {
    throw const FormatException('damaged snapshots');
  }

  @override
  Future<void> save(List<SavedTerminalTab> tabs) async {
    saveCalls++;
  }
}
