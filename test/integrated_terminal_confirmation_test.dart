import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/pages/command_generator_page.dart';
import 'package:terminal_master/widgets/terminal_panel.dart';

import 'support/fake_terminal_backend.dart';

void main() {
  testWidgets('stages a command without execution confirmation', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('terminal-confirm-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final config = File('${directory.path}/echo.yaml')
      ..writeAsStringSync('''
schema_version: 1
command: echo
description: Echo test
parameters:
  - name: message
    type: text
    description: Message
    required: true
''');
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
              builder: (context) =>
                  CommandGeneratorPage(configPath: config.path),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.text('Ins Terminal einfügen'));
    await tester.pumpAndSettle();

    expect(find.text('Kommando prüfen'), findsNothing);
    expect(factory.backends, hasLength(1));
    expect(factory.backends.single.writes, isEmpty);
    final input = tester.widget<TextField>(
      find.byKey(const Key('terminal-command-input')),
    );
    expect(input.controller!.text, 'echo hello');
    expect(find.text('Echo test'), findsOneWidget);
    expect(find.byKey(const Key('terminal-side-panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('hide-terminal-panel')));
    await tester.pump();
    expect(find.byKey(const Key('terminal-side-panel')), findsNothing);

    await tester.tap(find.byKey(const Key('terminal-panel-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('terminal-side-panel')), findsOneWidget);
    final reopenedInput = tester.widget<TextField>(
      find.byKey(const Key('terminal-command-input')),
    );
    expect(reopenedInput.controller!.text, 'echo hello');
  });
}
