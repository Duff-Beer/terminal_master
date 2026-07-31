import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/app.dart';

void main() {
  testWidgets('shows an empty configuration directory', (tester) async {
    final directory =
        Directory.systemTemp.createTempSync('terminal-master-ui-');
    addTearDown(() => directory.deleteSync(recursive: true));

    await tester.pumpWidget(
      MyApp(
        configDirectoryPath: directory.path,
        displayPath: directory.path,
      ),
    );

    expect(find.text('Terminal Command Generator'), findsOneWidget);
    expect(find.text('No config files found'), findsOneWidget);
  });
}
