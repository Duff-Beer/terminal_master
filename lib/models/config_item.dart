/// One entry in the Command Builder template list.
///
/// Holds data, never presentation text: [description] is whatever the YAML
/// file provided, and the empty, batch-count and failure cases are expressed
/// through [description] being null, [batchCommandCount] and [error]. The tile
/// turns those into localized strings.
class ConfigItem {
  final String command;
  final String? description;
  final String filePath;
  final bool isBatch;

  /// Number of commands in a batch file; null for single-command templates.
  final int? batchCommandCount;

  /// Why loading this file failed, or null when it loaded cleanly.
  final Object? error;

  ConfigItem({
    required this.command,
    this.description,
    required this.filePath,
    this.isBatch = false,
    this.batchCommandCount,
    this.error,
  });
}
