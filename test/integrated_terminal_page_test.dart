import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/pages/integrated_terminal_page.dart';

import 'support/fake_terminal_backend.dart';

void main() {
  testWidgets('opens one terminal tab per command and confirms shutdown', (
    tester,
  ) async {
    final factory = RecordingTerminalBackendFactory();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => IntegratedTerminalPage(
                  initialCommands: const ['echo one', 'echo two'],
                  backendFactory: factory.create,
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Integriertes Terminal'), findsOneWidget);
    expect(find.text('Terminal 1'), findsOneWidget);
    expect(find.text('Terminal 2'), findsOneWidget);
    expect(factory.backends, hasLength(2));
    expect(
      utf8.decode(factory.backends[0].writes.single),
      startsWith('echo one'),
    );
    expect(
      utf8.decode(factory.backends[1].writes.single),
      startsWith('echo two'),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Terminal schließen?'), findsOneWidget);

    await tester.tap(find.text('Prozesse beenden'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(
      factory.backends.every(
        (backend) => backend.exitCodeCompleter.isCompleted,
      ),
      isTrue,
    );
  });
}
