import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

/// Regression tests for copying text out of the vendored `packages/xterm`
/// buffer.
void main() {
  String firstLine(String output, {int? from, int? to}) {
    final terminal = Terminal()..write(output);
    return terminal.buffer.lines[0].getText(from, to);
  }

  test('keeps cells skipped by tabs and cursor movement as spaces', () {
    expect(firstLine('a\tb'), 'a       b');
    expect(firstLine('ls\x1b[3Cfoo'), 'ls   foo');
    expect(firstLine('x\x1b[1;6Hy'), 'x    y');
  });

  test('drops empty cells at the end of the line', () {
    expect(firstLine('end\t'), 'end');
    expect(firstLine('a\tb', to: 5), 'a');
  });

  test('keeps spaces written by the program', () {
    expect(firstLine('a  b  '), 'a  b  ');
  });

  test('does not add a space after wide characters', () {
    expect(firstLine('日本\tx'), '日本    x');
    expect(firstLine('日本', from: 1), '本');
  });

  test('copies a selection across empty cells', () {
    final terminal = Terminal()..write('name\tsize\r\nfile\t42');
    final text = terminal.buffer.getText(
      BufferRangeLine(const CellOffset(0, 0), const CellOffset(20, 1)),
    );
    expect(text, 'name    size\nfile    42');
  });
}
