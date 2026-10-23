import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/app.dart';
import 'package:terminal_master/models/shell_profile.dart';

import 'support/fake_terminal_backend.dart';

void main() {
  testWidgets('switches the interface language and persists the choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-l10n-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final factory = RecordingTerminalBackendFactory();
    final savedLanguages = <String?>[];

    await tester.pumpWidget(
      MyApp(
        configDirectoryPath: directory.path,
        displayPath: directory.path,
        terminalBackendFactory: factory.create,
        shellProfiles: const [
          ShellProfile(
            id: 'primary',
            name: 'Primary Shell',
            executable: '/bin/primary',
            dialect: ShellDialect.posix,
          ),
        ],
        languageCode: 'en',
        saveLanguage: (code) async => savedLanguages.add(code),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-panel-toggle')));
    await tester.pumpAndSettle();

    // Starts in English because `languageCode: 'en'` was passed in.
    expect(find.text('Settings').hitTestable(), findsOneWidget);
    expect(find.text('Language').hitTestable(), findsOneWidget);

    await tester.tap(find.byKey(const Key('ui-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();

    expect(savedLanguages, ['de']);
    // The whole interface follows, not just the settings page.
    expect(find.text('Einstellungen').hitTestable(), findsOneWidget);
    expect(find.text('Sprache').hitTestable(), findsOneWidget);
    expect(find.text('Sprache wurde gespeichert.'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('offers the system option and stores it as null', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-l10n-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final factory = RecordingTerminalBackendFactory();
    final savedLanguages = <String?>[];

    await tester.pumpWidget(
      MyApp(
        configDirectoryPath: directory.path,
        displayPath: directory.path,
        terminalBackendFactory: factory.create,
        shellProfiles: const [
          ShellProfile(
            id: 'primary',
            name: 'Primary Shell',
            executable: '/bin/primary',
            dialect: ShellDialect.posix,
          ),
        ],
        languageCode: 'de',
        saveLanguage: (code) async => savedLanguages.add(code),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-panel-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen').hitTestable(), findsOneWidget);

    await tester.tap(find.byKey(const Key('ui-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Systemsprache').last);
    await tester.pumpAndSettle();

    // `null` is what "follow the operating system" persists as.
    expect(savedLanguages, [null]);
  });
}
