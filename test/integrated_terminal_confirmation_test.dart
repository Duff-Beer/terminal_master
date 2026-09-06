import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/pages/batch_command_page.dart';
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
    await tester.tap(find.byKey(const Key('configuration-panel-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('parameter-message')),
        matching: find.byType(TextField),
      ),
      'hello',
    );
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
    expect(find.byKey(const Key('terminal-workspace')), findsOneWidget);
    expect(
      find.byKey(const Key('configuration-panel')).hitTestable(),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('configuration-panel-toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('configuration-panel')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Echo test').hitTestable(), findsOneWidget);
    final reopenedInput = tester.widget<TextField>(
      find.byKey(const Key('terminal-command-input')),
    );
    expect(reopenedInput.controller!.text, 'echo hello');
  });

  testWidgets('stages one batch command from its play action', (tester) async {
    final directory = Directory.systemTemp.createTempSync('terminal-batch-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final config = File('${directory.path}/-batch.yaml')
      ..writeAsStringSync('''
schema_version: 1
commands:
  - title: Working directory
    description: Show current directory
    command: pwd
  - title: List files
    command: ls -la
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
              builder: (context) => BatchCommandPage(filePath: config.path),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('configuration-panel-toggle')));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.byKey(const Key('stage-batch-command-0')));
    await tester.pumpAndSettle();

    expect(find.text('Kommando prüfen'), findsNothing);
    expect(factory.backends, hasLength(1));
    expect(factory.backends.single.writes, isEmpty);
    final input = tester.widget<TextField>(
      find.byKey(const Key('terminal-command-input')),
    );
    expect(input.controller!.text, 'pwd');
    expect(
      find.byKey(const Key('configuration-panel')).hitTestable(),
      findsNothing,
    );
  });
}
