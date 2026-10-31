import '../models/shell_profile.dart';

/// Quotes [value] as a single POSIX shell word.
String quotePosix(String value) {
  if (value.isEmpty) return "''";
  if (RegExp(r'^[A-Za-z0-9_@%+=:,./-]+$').hasMatch(value)) return value;
  return "'${value.replaceAll("'", "'\"'\"'")}'";
}

/// Quotes [value] as a single cmd.exe argument.
///
/// cmd.exe has no way to escape `%`, `!` or `"` inside quotes, so callers that
/// must reject those characters have to check for them before quoting.
String quoteWindowsCmd(String value) {
  if (value.isEmpty) return '""';
  if (RegExp(r'^[A-Za-z0-9_@+=:,./\\-]+$').hasMatch(value)) return value;
  final trailingBackslashes = RegExp(r'\\+$').firstMatch(value)?.group(0);
  if (trailingBackslashes != null) {
    value = '$value$trailingBackslashes';
  }
  return '"$value"';
}

/// Quotes [value] as a single PowerShell argument.
String quotePowerShell(String value) {
  if (value.isEmpty) return "''";
  if (RegExp(r'^[A-Za-z0-9_@%+=:,./\\-]+$').hasMatch(value)) return value;
  return "'${value.replaceAll("'", "''")}'";
}

String quoteForShell(String value, ShellDialect dialect) => switch (dialect) {
  ShellDialect.posix => quotePosix(value),
  ShellDialect.windowsCmd => quoteWindowsCmd(value),
  ShellDialect.powerShell => quotePowerShell(value),
};

/// Builds the terminal input for paths dropped onto a terminal: each path is
/// quoted for [dialect] and followed by a space so typing can continue.
///
/// Paths containing line breaks or NUL are skipped because pasting them could
/// run a command. Returns an empty string when nothing is left to insert.
String droppedPathsInput(Iterable<String> paths, ShellDialect dialect) {
  final quoted = paths
      .where(
        (path) => path.isNotEmpty && !RegExp(r'[\r\n\u0000]').hasMatch(path),
      )
      .map((path) => quoteForShell(path, dialect));
  if (quoted.isEmpty) return '';
  return '${quoted.join(' ')} ';
}
