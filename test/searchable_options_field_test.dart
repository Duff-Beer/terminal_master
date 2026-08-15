import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/command_config.dart';
import 'package:terminal_master/widgets/searchable_options_field.dart';

void main() {
  testWidgets('does not overlap the label and empty optional value', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableOptionsField(
            label: 'username',
            description: 'Optional username',
            options: const [
              CommandOption(value: 'admin', description: 'Administrator'),
            ],
            value: null,
            required: false,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final labelRect = tester.getRect(find.text('username'));
    final valueRect = tester.getRect(find.text('Nicht verwenden'));

    expect(labelRect.bottom, lessThanOrEqualTo(valueRect.top));
  });

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

  testWidgets('adds and immediately selects a persistent option', (
    tester,
  ) async {
    String? selected;
    var addCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableOptionsField(
            label: 'host *',
            description: 'Target host',
            options: const [
              CommandOption(value: 'localhost', description: 'Local host'),
            ],
            value: selected,
            required: true,
            onChanged: (value) => selected = value,
            onAddOption: () async {
              addCalls++;
              return const CommandOption(
                value: 'new.example.com',
                description: 'New host',
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('searchable-options-field-host *')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-searchable-option')));
    await tester.pumpAndSettle();

    expect(addCalls, 1);
    expect(selected, 'new.example.com');
  });

  testWidgets('confirms deletion and clears a deleted selection', (
    tester,
  ) async {
    String? selected = 'stage.local';
    CommandOption? deletedOption;
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
            onDeleteOption: (option) async {
              deletedOption = option;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('searchable-options-field-host *')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('delete-searchable-option-stage.local')),
    );
    await tester.pumpAndSettle();
    expect(selected, 'stage.local');
    await tester.tap(find.byKey(const Key('confirm-delete-option')));
    await tester.pumpAndSettle();

    expect(deletedOption?.value, 'stage.local');
    expect(selected, isNull);
    expect(find.text('stage.local'), findsNothing);
    expect(find.text('dev.local'), findsOneWidget);
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
