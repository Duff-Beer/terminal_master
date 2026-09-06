import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/app.dart';

import 'support/fake_terminal_backend.dart';

void main() {
  testWidgets('opens the terminal maximized at startup', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-ui-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final factory = RecordingTerminalBackendFactory();

    await tester.pumpWidget(
      MyApp(
        configDirectoryPath: directory.path,
        displayPath: directory.path,
        terminalBackendFactory: factory.create,
      ),
    );
    await tester.pumpAndSettle();

    expect(factory.backends, hasLength(1));
    expect(
      tester.getSize(find.byKey(const Key('terminal-side-panel'))).width,
      1200,
    );
    expect(find.byKey(const Key('maximize-terminal-panel')), findsOneWidget);
  });
}
