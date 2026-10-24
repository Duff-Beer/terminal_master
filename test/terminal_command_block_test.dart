import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/terminal_command_block.dart';

void main() {
  group('TerminalCommandBlock', () {
    test('caps retained output and records truncation', () {
      final block = _block();
      block.appendOutput('a' * TerminalCommandBlock.maxOutputLength);
      block.appendOutput('discarded');

      expect(block.output, hasLength(TerminalCommandBlock.maxOutputLength));
      expect(block.outputTruncated, isTrue);
    });

    test('removes terminal control sequences and marker lines from output', () {
      final block = _block();
      block.appendOutput(
        'first\r\n\x1b[31mred\x1b[0m\r\n${block.marker}:0\r\n',
      );

      expect(block.output, 'first\nred');
      expect(block.output, isNot(contains(block.marker)));
    });

    test('retains the exit code and terminal status', () {
      final block = _block();
      block.finish(7);

      expect(block.exitCode, 7);
      expect(block.finishedAt, isNotNull);
      expect(block.status, TerminalCommandBlockStatus.failed);
    });
  });
}

TerminalCommandBlock _block() => TerminalCommandBlock(
  id: 'test-block',
  command: 'echo test',
  startedAt: DateTime.utc(2025),
  marker: '__TEST_END_MARKER__',
);
