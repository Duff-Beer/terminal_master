import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/shell_profile.dart';
import 'package:terminal_master/utils/shell_quoting.dart';

void main() {
  group('droppedPathsInput', () {
    test('leaves simple posix paths unquoted and appends a space', () {
      expect(
        droppedPathsInput(['/home/user/file.txt'], ShellDialect.posix),
        '/home/user/file.txt ',
      );
    });

    test('quotes posix paths with spaces, quotes and shell characters', () {
      expect(
        droppedPathsInput([
          '/home/user/My Files/a.txt',
          "/tmp/it's.txt",
          r'/tmp/$HOME & more',
          '/tmp/Übung.pdf',
        ], ShellDialect.posix),
        "'/home/user/My Files/a.txt' '/tmp/it'\"'\"'s.txt' "
        r"'/tmp/$HOME & more' '/tmp/Übung.pdf' ",
      );
    });

    test('quotes Windows paths for PowerShell', () {
      expect(
        droppedPathsInput([
          r'C:\Users\me\file.txt',
          r"C:\Users\me\My Docs\it's.txt",
        ], ShellDialect.powerShell),
        r"C:\Users\me\file.txt 'C:\Users\me\My Docs\it''s.txt' ",
      );
    });

    test('quotes Windows paths for cmd.exe', () {
      expect(
        droppedPathsInput([
          r'C:\Users\me\My Docs\file.txt',
          r'C:\Program Files\',
        ], ShellDialect.windowsCmd),
        r'"C:\Users\me\My Docs\file.txt" "C:\Program Files\\" ',
      );
    });

    test('skips empty paths and paths with line breaks', () {
      expect(
        droppedPathsInput([
          '',
          '/tmp/evil\nrm -rf ~',
          '/tmp/ok',
        ], ShellDialect.posix),
        '/tmp/ok ',
      );
      expect(droppedPathsInput(['/tmp/a\rb'], ShellDialect.posix), '');
      expect(droppedPathsInput(const [], ShellDialect.posix), '');
    });
  });
}
