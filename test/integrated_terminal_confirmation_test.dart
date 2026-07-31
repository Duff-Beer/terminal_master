import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/pages/command_generator_page.dart';

import 'support/fake_terminal_backend.dart';

void main() {
  testWidgets('does not create a PTY before command confirmation', (
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

    await tester.pumpWidget(
      MaterialApp(
        home: CommandGeneratorPage(
          configPath: config.path,
          terminalBackendFactory: factory.create,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.text('Kommando ausführen'));
    await tester.pumpAndSettle();

    expect(find.text('Kommando prüfen'), findsOneWidget);
    expect(factory.backends, isEmpty);

    await tester.tap(find.byKey(const Key('confirm-command-execution')));
    await tester.pumpAndSettle();

    expect(factory.backends, hasLength(1));
    expect(
      utf8.decode(factory.backends.single.writes.single),
      startsWith('echo hello'),
    );
  });
}
