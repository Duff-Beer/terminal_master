import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

/// Regression tests for the escape sequence fixes in the vendored
/// `packages/xterm`.
void main() {
  CellData cellAfter(String sequence) {
    final terminal = Terminal()
      ..write(
        '$sequence'
        'X',
      );
    final cell = CellData.empty();
    terminal.buffer.lines[terminal.buffer.absoluteCursorY].getCellData(
      terminal.buffer.cursorX - 1,
      cell,
    );
    return cell;
  }

  bool has(CellData cell, int flag) => cell.flags & flag != 0;

  test('ignores XTMODKEYS instead of applying it as SGR', () {
    for (final sequence in ['\x1b[>4;2m', '\x1b[>4m', '\x1b[?4m']) {
      final cell = cellAfter(sequence);
      expect(has(cell, CellFlags.underline), isFalse, reason: sequence);
      expect(has(cell, CellFlags.faint), isFalse, reason: sequence);
    }
  });

  test('does not set margins for XTRESTORE', () {
    final terminal = Terminal()..write('\x1b[?1;2r');
    expect(terminal.buffer.marginTop, 0);
    expect(terminal.buffer.marginBottom, terminal.viewHeight - 1);
  });

  test('ignores CSI sequences with intermediate bytes', () {
    final terminal = Terminal()..write('\x1b[5;5H\x1b[3 A');
    expect(terminal.buffer.cursorY, 4);
  });

  test('keeps supported prefixed sequences', () {
    final terminal = Terminal()..write('\x1b[?25l');
    expect(terminal.cursorVisibleMode, isFalse);
  });

  test('parses colon separated underline styles', () {
    final curly = cellAfter('\x1b[4:3m');
    expect(has(curly, CellFlags.underline), isTrue);
    expect(curly.background, 0);

    final off = cellAfter('\x1b[4m\x1b[4:0m');
    expect(has(off, CellFlags.underline), isFalse);
    expect(off.background, 0);
  });

  test('parses colon separated colors', () {
    final withColorSpace = cellAfter('\x1b[38:2::255:128:0m');
    expect(withColorSpace.foreground & CellColor.valueMask, 0xff8000);
    expect(withColorSpace.foreground & CellColor.typeMask, CellColor.rgb);

    final withoutColorSpace = cellAfter('\x1b[48:2:1:2:3m');
    expect(withoutColorSpace.background & CellColor.valueMask, 0x010203);

    final indexed = cellAfter('\x1b[38:5:208m');
    expect(indexed.foreground & CellColor.valueMask, 208);
    expect(indexed.foreground & CellColor.typeMask, CellColor.palette);
  });

  test('ignores unsupported sub-parameters without side effects', () {
    final cell = cellAfter('\x1b[1;58:2::255:0:0;3m');
    expect(has(cell, CellFlags.bold), isTrue);
    expect(has(cell, CellFlags.italic), isTrue);
    expect(cell.background, 0);
  });

  test('still parses semicolon separated SGR', () {
    final cell = cellAfter('\x1b[4;38;2;255;128;0m');
    expect(has(cell, CellFlags.underline), isTrue);
    expect(cell.foreground & CellColor.valueMask, 0xff8000);
  });
}
