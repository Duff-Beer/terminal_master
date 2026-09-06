import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/app.dart';

import 'support/fake_terminal_backend.dart';

void main() {
  testWidgets('opens config over the persistent terminal workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-ui-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final factory = RecordingTerminalBackendFactory();

    await tester.pumpWidget(
      MyApp(
        configDirectoryPath: directory.path,
        displayPath: directory.path,
        terminalBackendFactory: factory.create,
      ),
    );
    await tester.pumpAndSettle();

    expect(factory.backends, hasLength(1));
    expect(
      tester.getSize(find.byKey(const Key('workspace-tool-rail'))).width,
      48,
    );
    expect(
      tester.getSize(find.byKey(const Key('terminal-workspace'))).width,
      1152,
    );
    expect(
      find.byKey(const Key('configuration-panel')).hitTestable(),
      findsNothing,
    );
    expect(find.byKey(const Key('maximize-terminal-panel')), findsNothing);
    expect(find.byKey(const Key('hide-terminal-panel')), findsNothing);
    expect(find.byKey(const Key('ssh-panel-toggle')), findsOneWidget);

    await tester.tap(find.byKey(const Key('configuration-panel-toggle')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('configuration-panel')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Command Builder').hitTestable(), findsOneWidget);
    expect(find.text('No config files found').hitTestable(), findsOneWidget);
    expect(factory.backends, hasLength(1));
    expect(
      tester.getSize(find.byKey(const Key('terminal-workspace'))).width,
      1152,
    );
    final configSearch = find.descendant(
      of: find.byKey(const Key('configuration-tool-content')),
      matching: find.byType(TextField),
    );
    await tester.enterText(configSearch, 'remember me');

    await tester.tap(find.byKey(const Key('ssh-panel-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('SSH-Verbindungen').hitTestable(), findsOneWidget);
    expect(
      find.text('Noch keine SSH-Verbindungen gespeichert.').hitTestable(),
      findsOneWidget,
    );
    expect(factory.backends, hasLength(1));

    await tester.tap(find.byKey(const Key('configuration-panel-toggle')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(configSearch).controller!.text,
      'remember me',
    );

    await tester.tap(find.byKey(const Key('configuration-panel-barrier')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('configuration-panel')).hitTestable(),
      findsNothing,
    );
    expect(factory.backends, hasLength(1));
  });
}
