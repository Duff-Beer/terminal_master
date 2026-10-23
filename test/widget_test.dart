import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/app.dart';
import 'package:terminal_master/models/shell_profile.dart';

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
    String? savedDefaultProfileId;
    String? savedYamlDirectoryPath;
    final yamlDirectory = Directory('${directory.path}/yaml')..createSync();
    File('${yamlDirectory.path}/echo.yaml').writeAsStringSync('''
schema_version: 1
command: echo
description: Echo text
parameters: []
''');
    const profiles = [
      ShellProfile(
        id: 'primary',
        name: 'Primary Shell',
        executable: '/bin/primary',
        dialect: ShellDialect.posix,
      ),
      ShellProfile(
        id: 'secondary',
        name: 'Secondary Shell',
        executable: '/bin/secondary',
        dialect: ShellDialect.posix,
      ),
    ];

    await tester.pumpWidget(
      MyApp(
        configDirectoryPath: directory.path,
        displayPath: directory.path,
        terminalBackendFactory: factory.create,
        shellProfiles: profiles,
        // Pinned so the German expectations below stay independent of the
        // locale the test host happens to run in.
        languageCode: 'de',
        saveDefaultShellProfile: (profileId) async {
          savedDefaultProfileId = profileId;
        },
        saveYamlDirectoryPath: (path) async {
          savedYamlDirectoryPath = path;
        },
        selectYamlDirectory: () async => yamlDirectory.path,
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
    expect(find.byKey(const Key('settings-panel-toggle')), findsOneWidget);

    await tester.tap(find.byKey(const Key('configuration-panel-toggle')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('configuration-panel')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Command Builder').hitTestable(), findsOneWidget);
    expect(
      find.text('Keine Konfigurationsdateien gefunden').hitTestable(),
      findsOneWidget,
    );
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

    await tester.tap(find.byKey(const Key('settings-panel-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen').hitTestable(), findsOneWidget);
    expect(
      find.byKey(const Key('default-shell-profile')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('default-shell-profile')));
    await tester.pumpAndSettle();
    expect(
      find.byType(DropdownMenuItem<String>).hitTestable(),
      findsNWidgets(2),
    );
    await tester.tap(find.byType(DropdownMenuItem<String>).hitTestable().last);
    await tester.pumpAndSettle();
    expect(savedDefaultProfileId, 'secondary');
    await tester.tap(find.byKey(const Key('select-yaml-directory')));
    await tester.pumpAndSettle();
    expect(savedYamlDirectoryPath, yamlDirectory.path);
    expect(find.text(yamlDirectory.path), findsOneWidget);

    await tester.tap(find.byKey(const Key('configuration-panel-toggle')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(configSearch).controller!.text,
      'remember me',
    );
    await tester.enterText(configSearch, '');
    await tester.pumpAndSettle();
    expect(find.text('echo').hitTestable(), findsOneWidget);

    await tester.tap(find.byKey(const Key('configuration-panel-barrier')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('configuration-panel')).hitTestable(),
      findsNothing,
    );
    expect(factory.backends, hasLength(1));

    await tester.tap(find.byKey(const Key('new-terminal-tab')));
    await tester.pumpAndSettle();
    expect(factory.backends, hasLength(2));
    expect(factory.options.last.executable, '/bin/secondary');
  });
}
