import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/shell_profile.dart';

void main() {
  test('names the login shell after its executable', () {
    final configuredShell = Platform.environment['SHELL'] ?? '/bin/bash';
    if (!File(configuredShell).existsSync()) return;

    final profile = ShellProfile.platformDefaults().firstWhere(
      (profile) => profile.id == 'login-shell',
    );

    expect(profile.executable, configuredShell);
    expect(profile.name, configuredShell.split('/').last);
  });
}
