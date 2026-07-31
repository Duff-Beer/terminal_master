class BatchCommand {
  final String title;
  final String description;
  final String command;

  const BatchCommand({
    required this.title,
    required this.description,
    required this.command,
  });
}

class BatchCommandConfig {
  final List<BatchCommand> commands;

  const BatchCommandConfig({required this.commands});
}
