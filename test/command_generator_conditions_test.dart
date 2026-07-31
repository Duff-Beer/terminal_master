import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/pages/command_generator_page.dart';

void main() {
  testWidgets('updates conditional fields and supports multiple values', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('condition-widget-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final config = File('${directory.path}/config.yaml')
      ..writeAsStringSync('''
schema_version: 1
command: demo
parameters:
  - name: show_advanced
    type: boolean
    description: Show advanced fields
  - name: advanced_value
    type: text
    description: Advanced value
    visible_when:
      parameter: show_advanced
      equals: true
  - name: targets
    type: text_list
    description: Targets
    required: true
  - name: mode
    type: options
    description: Optional mode
    options:
      - value: basic
        description: Basic mode
      - value: __terminal_master_unset_option__
        description: Reserved-looking user value
''');

    await tester.pumpWidget(
      MaterialApp(home: CommandGeneratorPage(configPath: config.path)),
    );

    expect(find.text('advanced_value'), findsNothing);
    expect(find.text('targets 1 *'), findsOneWidget);
    expect(find.text('Nicht verwenden'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'targets 1 *'),
      'first.example',
    );

    await tester.tap(find.text('show_advanced'));
    await tester.pump();
    expect(find.text('advanced_value'), findsOneWidget);
    expect(find.text('first.example'), findsOneWidget);

    await tester.tap(find.text('Weiteren Eintrag hinzufügen'));
    await tester.pump();
    expect(find.text('targets 2 *'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'targets 2 *'),
      'second.example',
    );
    expect(find.text('first.example'), findsOneWidget);
    expect(find.text('second.example'), findsOneWidget);

    await tester.tap(find.text('Nicht verwenden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('basic: Basic mode').last);
    await tester.pumpAndSettle();
    expect(find.text('basic: Basic mode'), findsOneWidget);

    await tester.tap(find.text('basic: Basic mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nicht verwenden').last);
    await tester.pumpAndSettle();
    expect(find.text('Nicht verwenden'), findsOneWidget);
  });
}
