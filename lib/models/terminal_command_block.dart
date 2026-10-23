enum TerminalCommandBlockStatus { running, succeeded, failed, interrupted }

class TerminalCommandBlock {
  /// Hard cap on retained output per block. Public so the UI can name the
  /// limit in its localized truncation notice.
  static const maxOutputLength = 500000;

  final String id;
  final String command;
  final DateTime startedAt;
  final String marker;
  final StringBuffer _output = StringBuffer();

  TerminalCommandBlock({
    required this.id,
    required this.command,
    required this.startedAt,
    required this.marker,
  });

  TerminalCommandBlockStatus status = TerminalCommandBlockStatus.running;
  DateTime? finishedAt;
  int? exitCode;
  bool outputTruncated = false;
  var _outputLength = 0;

  Duration get duration => (finishedAt ?? DateTime.now()).difference(startedAt);

  String get output {
    final withoutControlSequences = _output
        .toString()
        .replaceAll(RegExp(r'\x1b\[[0-?]*[ -/]*[@-~]'), '')
        .replaceAll(RegExp(r'\x1b\][^\x07]*(?:\x07|\x1b\\)'), '');
    return withoutControlSequences
        .split(RegExp(r'\r?\n'))
        .where((line) => !line.contains(marker))
        .join('\n')
        .trim();
  }

  void appendOutput(String value) {
    if (value.isEmpty || outputTruncated) return;
    final remaining = maxOutputLength - _outputLength;
    if (value.length <= remaining) {
      _output.write(value);
      _outputLength += value.length;
      return;
    }
    if (remaining > 0) {
      _output.write(value.substring(0, remaining));
      _outputLength += remaining;
    }
    outputTruncated = true;
  }

  void finish(int code) {
    exitCode = code;
    finishedAt = DateTime.now();
    status = code == 0
        ? TerminalCommandBlockStatus.succeeded
        : TerminalCommandBlockStatus.failed;
  }

  void interrupt([int? code]) {
    exitCode = code;
    finishedAt = DateTime.now();
    status = TerminalCommandBlockStatus.interrupted;
  }

  String toMarkdown() {
    final code = exitCode?.toString() ?? 'unbekannt';
    final outputText = output.isEmpty ? '(keine Ausgabe)' : output;
    return '''# Terminal Command

- Status: ${status.name}
- Exit-Code: $code
- Start: ${startedAt.toIso8601String()}
- Dauer: ${duration.inMilliseconds} ms
- Ausgabe gekürzt: ${outputTruncated ? 'ja' : 'nein'}

```sh
$command
```

```text
$outputText
```
''';
  }
}
