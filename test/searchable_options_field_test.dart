import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/command_config.dart';
import 'package:terminal_master/widgets/searchable_options_field.dart';

void main() {
  testWidgets('filters by value and description and selects with keyboard', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableOptionsField(
            label: 'host *',
            description: 'Target host',
            options: const [
              CommandOption(value: 'dev.local', description: 'Development'),
              CommandOption(
                value: 'production.example.com',
                description: 'Primary production server',
              ),
            ],
            value: selected,
            required: true,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('searchable-options-field-host *')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('searchable-options-query')),
      'PRIMARY PRODUCTION',
    );
    await tester.pump();
    expect(find.text('production.example.com'), findsOneWidget);
    expect(find.text('dev.local'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(selected, 'production.example.com');
  });

  testWidgets('moves through results with arrow keys and cancels with Escape', (
    tester,
  ) async {
    String? selected = 'dev.local';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableOptionsField(
            label: 'host *',
            description: 'Target host',
            options: const [
              CommandOption(value: 'dev.local', description: 'Development'),
              CommandOption(value: 'stage.local', description: 'Staging'),
            ],
            value: selected,
            required: true,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('searchable-options-field-host *')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 'stage.local');

    await tester.tap(find.byKey(const Key('searchable-options-field-host *')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(selected, 'stage.local');
  });

  testWidgets('shows no matches and remains usable in a short window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableOptionsField(
            label: 'mode',
            description: 'Optional mode',
            options: List.generate(
              40,
              (index) => CommandOption(
                value: 'mode-$index',
                description: 'Mode number $index',
              ),
            ),
            value: null,
            required: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('searchable-options-field-mode')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('searchable-options-query')),
      'missing',
    );
    await tester.pump();

    expect(find.text('Keine Treffer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
