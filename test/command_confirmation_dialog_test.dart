import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';
import 'package:terminal_master/services/command_risk_assessor.dart';
import 'package:terminal_master/widgets/command_confirmation_dialog.dart';

void main() {
  testWidgets('destructive execution requires explicit acknowledgement', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showCommandConfirmationDialog(
                context,
                commands: const ['sudo rm -rf /tmp/example'],
                assessment: const CommandRiskAssessment(
                  level: CommandRiskLevel.destructive,
                  reasons: [CommandRiskReason.rmDeletesPermanently],
                  containsRawConfiguration: true,
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Destruktives Kommando bestätigen'), findsOneWidget);
    expect(find.text('sudo rm -rf /tmp/example'), findsOneWidget);
    expect(find.textContaining('YAML-Datei'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-command-execution')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('command-risk-acknowledgement')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-command-execution')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('confirm-command-execution')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
